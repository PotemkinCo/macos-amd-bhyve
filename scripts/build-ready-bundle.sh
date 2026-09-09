#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"

usage() {
    cat >&2 <<'EOF'
usage: build-ready-bundle.sh CLEAN_EDK2_CHECKOUT OUTPUT_DIRECTORY [CORE_COUNT]

Builds the patched bhyve firmware, a fresh UEFI variables template, the
OpenCore EFI tree, a GPT OpenCore disk image, generated identities, and one
ready-bundle archive. CORE_COUNT defaults to 4.
EOF
}

if (($# < 2 || $# > 3)); then
    usage
    exit 64
fi

edk2_checkout="$1"
output_arg="$2"
core_count="${3:-4}"
[[ "$core_count" =~ ^[0-9]+$ ]] || {
    echo "build-ready-bundle: CORE_COUNT must be an integer" >&2
    exit 1
}

output_parent="$(dirname -- "$output_arg")"
output_name="$(basename -- "$output_arg")"
mkdir -p -- "$output_parent"
output_parent="$(cd -- "$output_parent" && pwd -P)"
output_dir="$output_parent/$output_name"
[[ ! -e "$output_dir" ]] || {
    echo "build-ready-bundle: output already exists: $output_dir" >&2
    exit 1
}

work_root="$(mktemp -d "${TMPDIR:-/tmp}/macos-amd-bhyve-ready.XXXXXXXX")"
cleanup() {
    rm -rf -- "$work_root"
}
trap cleanup EXIT HUP INT TERM

mkdir -p -- "$work_root/firmware"
"$SCRIPT_DIR/build-edk2-bhyve.sh" "$edk2_checkout" "$work_root/firmware"
"$SCRIPT_DIR/assemble-opencore.sh" --cores "$core_count" "$work_root/opencore"

mv -- "$work_root/opencore" "$work_root/product"
cp -- "$work_root/firmware/BHYVE_CODE.fd" "$work_root/product/BHYVE_CODE.fd"
cp -- "$work_root/firmware/BHYVE_UEFI.fd" "$work_root/product/BHYVE_UEFI.fd"
cp -- "$work_root/firmware/BHYVE_UEFI_VARS.fd" "$work_root/product/BHYVE_UEFI_VARS.fd"
rm -f -- "$work_root/product/macos-amd-bhyve-ready.tar.gz" \
    "$work_root/product/SHA256SUMS"

cp -- "$SCRIPT_DIR/../templates/README-FIRST.txt" "$work_root/product/README-FIRST.txt"

tar -C "$work_root/product" -czf "$work_root/product/macos-amd-bhyve-ready.tar.gz" \
    BHYVE_CODE.fd BHYVE_UEFI.fd BHYVE_UEFI_VARS.fd EFI LICENSES NOTICE \
    README-FIRST.txt identity.env macos.conf.example opencore.img patches.plist

(
    cd -- "$work_root/product"
    while IFS= read -r file; do
        if command -v sha256sum >/dev/null 2>&1; then
            digest="$(sha256sum "$file" | awk '{print $1}')"
        else
            digest="$(sha256 -q "$file")"
        fi
        printf '%s  %s\n' "$digest" "$file"
    done < <(find . -type f ! -name SHA256SUMS -print | LC_ALL=C sort)
) > "$work_root/product/SHA256SUMS"

mv -- "$work_root/product" "$output_dir"
trap - EXIT HUP INT TERM
rm -rf -- "$work_root"

echo "Ready bundle created at $output_dir"
