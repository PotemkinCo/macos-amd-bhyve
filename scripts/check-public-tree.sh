#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly EXPECTED_SSDT_SHA256="a858e947ace143768e2a3b825d6fe97c8c7d7cafe79be2fc0dae844c35965264"
cd -- "$REPO_ROOT"

fail() {
    echo "PUBLIC_TREE_REJECTED: $*" >&2
    exit 1
}

command -v git >/dev/null || fail "git is required"
command -v python3 >/dev/null || fail "python3 is required"

for required in \
    LICENSE NOTICE LICENSES/EDK2-BSD-2-Clause-Patent.txt \
    LICENSES/OpenCorePkg-BSD-3-Clause.txt \
    LICENSES/Lilu-BSD-3-Clause.txt LICENSES/VirtualSMC-BSD-3-Clause.txt \
    LICENSES/WhateverGreen-BSD-3-Clause.txt \
    LICENSES/CryptexFixup-BSD-3-Clause.txt LICENSES/GPL-2.0.txt \
    provenance/inputs.json provenance/payload.sha256 \
    acpi/SSDT-BHYVE-CPU.dsl \
    patches/edk2/0001-bhyve-filebuffer-image-verification.patch \
    opencore/EFI/OC/config.plist; do
    [[ -f "$required" ]] || fail "missing required file: $required"
done

source_sha256="$(python3 -c 'import hashlib; print(hashlib.sha256(open("acpi/SSDT-BHYVE-CPU.dsl", "rb").read()).hexdigest())')"
[[ "$source_sha256" == "$EXPECTED_SSDT_SHA256" ]] ||
    fail "SSDT source hash changed: $source_sha256"

python3 -m json.tool provenance/inputs.json >/dev/null ||
    fail "invalid provenance JSON"
python3 scripts/verify-public-payload.py

grep -F "DxeImageVerificationLib.c" patches/edk2/0001-bhyve-filebuffer-image-verification.patch >/dev/null ||
    fail "EDK2 patch target missing"
grep -F "FileBuffer == NULL" patches/edk2/0001-bhyve-filebuffer-image-verification.patch >/dev/null ||
    fail "EDK2 FileBuffer guard missing"
if grep -F "ExceptionHandlerAsm" patches/edk2/0001-bhyve-filebuffer-image-verification.patch >/dev/null; then
    fail "diagnostic exception-vector patch included"
fi

while IFS= read -r -d '' file; do
    relative="${file#./}"
    case "$relative" in
        .git/*)
            continue
            ;;
    esac

    case "$relative" in
        *.img|*.qcow2|*.raw|*.dmg|*.iso|*.log|*.png|*.pcap|*.cap|*.tar|*.tgz|*.gz|*.zip|*.7z)
            fail "generated VM/media/archive payload is present: $relative"
            ;;
        *.fd)
            case "$relative" in
                firmware/BHYVE_UEFI.fd|firmware/BHYVE_UEFI_VARS.fd) ;;
                *) fail "unapproved firmware payload is present: $relative" ;;
            esac
            ;;
        *.efi)
            case "$relative" in
                opencore/EFI/BOOT/BOOTx64.efi|opencore/EFI/OC/OpenCore.efi|opencore/EFI/OC/Drivers/*.efi) ;;
                *) fail "unapproved EFI payload is present: $relative" ;;
            esac
            ;;
        *.aml)
            [[ "$relative" == "opencore/EFI/OC/ACPI/SSDT-EC.aml" ||
                "$relative" == "opencore/EFI/OC/ACPI/SSDT-BHYVE-CPU.aml" ]] ||
                fail "generated or unapproved AML is present: $relative"
            ;;
    esac

    bytes="$(wc -c < "$file")"
    if ((bytes > 1048576)); then
        case "$relative" in
            firmware/BHYVE_UEFI.fd) ;;
            *) fail "unexpectedly large file: $relative ($bytes bytes)" ;;
        esac
    fi

    if [[ "$relative" != "scripts/check-public-tree.sh" ]]; then
        if grep -I -n -E '(/home/|/tank/|/Users/|/private/|192[.]168[.]|10[.][0-9]+[.][0-9]+[.][0-9]+|172[.](1[6-9]|2[0-9]|3[01])[.])' "$file" >/dev/null; then
            fail "private path or network address found: $relative"
        fi
        if grep -I -n -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' "$file" >/dev/null; then
            fail "MAC address found in public source: $relative"
        fi
        if grep -I -n -E 'BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|xox[baprs]-|gh[pousr]_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}' "$file" >/dev/null; then
            fail "credential material found: $relative"
        fi
    fi
done < <(find . -type f -not -path './.git/*' -print0)

git diff --check
echo "PUBLIC_TREE_OK"
