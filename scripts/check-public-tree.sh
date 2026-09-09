#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail() {
    echo "PUBLIC_TREE_REJECTED: $*" >&2
    exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v sha256 >/dev/null 2>&1 || fail "sha256 is required"

[ -f LICENSE ] || fail "missing LICENSE"
[ -f README.md ] || fail "missing README.md"
[ -f acpi/SSDT-BHYVE-CPU.dsl ] || fail "missing SSDT source"
[ -f patches/edk2-known-good-baseline-dxe.patch ] ||
    fail "missing isolated EDK2 patch"
[ -f provenance/preserved-inputs.md ] || fail "missing provenance"

source_sha256=$(sha256 -q acpi/SSDT-BHYVE-CPU.dsl)
[ "$source_sha256" = "a858e947ace143768e2a3b825d6fe97c8c7d7cafe79be2fc0dae844c35965264" ] ||
    fail "SSDT source hash changed: $source_sha256"

git diff --check

find . -type f -not -path './.git/*' -print | while IFS= read -r file; do
    relative=${file#./}

    case "$relative" in
        scripts/check-public-tree.sh)
            continue
            ;;
        *.aml|*.dmg|*.efi|*.fd|*.img|*.iso|*.kext|*.log|*.nvram|*.pcap|*.raw|*.vars|*.zip|*.tar|*.tgz|*.gz|*.7z|*.bin)
            fail "generated or binary payload is tracked: $relative"
            ;;
    esac

    bytes=$(wc -c < "$file")
    [ "$bytes" -le 1048576 ] || fail "unexpectedly large file: $relative ($bytes bytes)"

    if grep -I -n -E '(/home/|/tank/|/Users/|/private/|/tmp/|192[.]168[.]|10[.][0-9]+[.][0-9]+[.][0-9]+|172[.](1[6-9]|2[0-9]|3[01])[.])' "$file" >/dev/null 2>&1; then
        fail "private path or network address found: $relative"
    fi
    if grep -I -n -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}|<key>(MLB|ROM|SystemSerialNumber|SystemUUID)</key>' "$file" >/dev/null 2>&1; then
        fail "machine identity found: $relative"
    fi
    if grep -I -n -E 'BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|xox[baprs]-|gh[pousr]_[A-Za-z0-9_]+|AKIA[0-9A-Z]{16}' "$file" >/dev/null 2>&1; then
        fail "credential material found: $relative"
    fi
done

echo PUBLIC_TREE_OK
