#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

readonly AMD_PATCHES_FILE="AMD_Vanilla-eaf52ef2-patches.plist"
readonly AMD_PATCHES_URL="https://raw.githubusercontent.com/AMD-OSX/AMD_Vanilla/eaf52ef292abf4ebec899df6d48626569ba50cc6/patches.plist"
readonly AMD_PATCHES_SHA256="4bc820109b3d020c3c547fa23c49e0098e4f4a2c625ed6184dd54e390e84e1ab"

usage() {
    cat >&2 <<'EOF'
usage: assemble-opencore.sh [options] OUTPUT_DIRECTORY

Options:
  --cores NUMBER          Guest vCPU/core patch count (tested value: 4)
  --cache DIRECTORY       Download cache (default: /tmp/macos-amd-bhyve-cache)
  --system-serial VALUE   Existing iMacPro1,1 serial; requires --mlb
  --mlb VALUE             Existing iMacPro1,1 board serial; requires --system-serial
  --system-uuid UUID      Existing OpenCore SystemUUID (otherwise generated)
  --rom HEX               Six-byte ROM value, with or without colons (otherwise generated)
  --no-image              Build the EFI tree and archive, but not opencore.img

Without --system-serial/--mlb, the pinned OpenCore macserial utility generates
a fresh pair. On FreeBSD this requires the Linux ABI to run its static Linux
binary. The output directory must not already exist.
EOF
}

fail() {
    echo "assemble-opencore: $*" >&2
    exit 1
}

file_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    else
        fail "sha256sum or sha256 is required"
    fi
}

verify_file() {
    local file="$1"
    local expected="$2"
    local actual
    actual="$(file_sha256 "$file")"
    [[ "$actual" == "$expected" ]] ||
        fail "SHA-256 mismatch for $file: expected $expected, got $actual"
}

download() {
    local url="$1"
    local expected="$2"
    local destination="$3"
    local partial="$destination.part.$$"

    if [[ -f "$destination" ]]; then
        verify_file "$destination" "$expected"
        return
    fi

    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 3 --output "$partial" "$url"
    elif command -v fetch >/dev/null 2>&1; then
        fetch -a -o "$partial" "$url"
    else
        fail "curl or fetch is required"
    fi
    verify_file "$partial" "$expected"
    mv -- "$partial" "$destination"
}

core_count=4
cache_dir="${TMPDIR:-/tmp}/macos-amd-bhyve-cache"
system_serial=""
mlb=""
system_uuid=""
rom=""
make_image=yes

while (($#)); do
    case "$1" in
        --cores)
            (($# >= 2)) || fail "--cores requires a value"
            core_count="$2"
            shift 2
            ;;
        --cache)
            (($# >= 2)) || fail "--cache requires a value"
            cache_dir="$2"
            shift 2
            ;;
        --system-serial)
            (($# >= 2)) || fail "--system-serial requires a value"
            system_serial="$2"
            shift 2
            ;;
        --mlb)
            (($# >= 2)) || fail "--mlb requires a value"
            mlb="$2"
            shift 2
            ;;
        --system-uuid)
            (($# >= 2)) || fail "--system-uuid requires a value"
            system_uuid="$2"
            shift 2
            ;;
        --rom)
            (($# >= 2)) || fail "--rom requires a value"
            rom="$2"
            shift 2
            ;;
        --no-image)
            make_image=no
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --*)
            fail "unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

(($# == 1)) || {
    usage
    exit 64
}
[[ "$core_count" =~ ^[0-9]+$ ]] || fail "--cores must be an integer"
((core_count == 4)) ||
    fail "this published ACPI/topology baseline supports exactly four vCPUs"
[[ -z "$system_serial" && -z "$mlb" || -n "$system_serial" && -n "$mlb" ]] ||
    fail "--system-serial and --mlb must be supplied together"

for command_name in python3 tar awk find sed; do
    command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done
python3 "$SCRIPT_DIR/verify-public-payload.py" >/dev/null
if [[ "$make_image" == yes ]]; then
    command -v makefs >/dev/null 2>&1 || fail "makefs is required (or use --no-image)"
    command -v mkimg >/dev/null 2>&1 || fail "mkimg is required (or use --no-image)"
fi

output_parent="$(dirname -- "$1")"
output_name="$(basename -- "$1")"
mkdir -p -- "$output_parent"
output_parent="$(cd -- "$output_parent" && pwd -P)"
output_dir="$output_parent/$output_name"
[[ ! -e "$output_dir" ]] || fail "output already exists: $output_dir"

mkdir -p -- "$cache_dir"
cache_dir="$(cd -- "$cache_dir" && pwd -P)"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/macos-amd-bhyve-opencore.XXXXXXXX")"
cleanup() {
    rm -rf -- "$work_root"
    rm -f -- "$cache_dir"/*.part.$$ 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

download "$AMD_PATCHES_URL" "$AMD_PATCHES_SHA256" "$cache_dir/$AMD_PATCHES_FILE"

product="$work_root/product"
efi="$product/EFI"
mkdir -p -- "$product"
cp -R -- "$REPO_ROOT/opencore/EFI" "$efi"

cp -- "$cache_dir/$AMD_PATCHES_FILE" "$product/patches.plist"
cp -- "$REPO_ROOT/firmware/BHYVE_UEFI.fd" "$product/BHYVE_UEFI.fd"
cp -- "$REPO_ROOT/firmware/BHYVE_UEFI_VARS.fd" "$product/BHYVE_UEFI_VARS.fd"
cp -- "$REPO_ROOT/NOTICE" "$product/NOTICE"
cp -R -- "$REPO_ROOT/LICENSES" "$product/LICENSES"
cp -- "$REPO_ROOT/templates/README-FIRST.txt" "$product/README-FIRST.txt"

configure_args=(
    --template "$REPO_ROOT/opencore/EFI/OC/config.plist"
    --patches "$product/patches.plist"
    --output "$efi/OC/config.plist"
    --identity-output "$product/identity.env"
    --core-count "$core_count"
)
if [[ -n "$system_serial" ]]; then
    configure_args+=(--system-serial "$system_serial" --mlb "$mlb")
else
    macserial="$REPO_ROOT/opencore/Utilities/macserial.linux"
    configure_args+=(--macserial "$macserial")
fi
[[ -z "$system_uuid" ]] || configure_args+=(--system-uuid "$system_uuid")
[[ -z "$rom" ]] || configure_args+=(--rom "$rom")
"$SCRIPT_DIR/configure-opencore.py" "${configure_args[@]}"

network_mac="$(sed -n 's/^NETWORK_MAC=//p' "$product/identity.env")"
vm_uuid="$(sed -n 's/^VM_UUID=//p' "$product/identity.env")"
[[ -n "$network_mac" && -n "$vm_uuid" ]] || fail "generated identity.env is incomplete"
sed \
    -e "s/REPLACE_WITH_GENERATED_MAC/$network_mac/" \
    -e "s/REPLACE_WITH_GENERATED_UUID/$vm_uuid/" \
    "$REPO_ROOT/vm-bhyve/dobby-tests-macos.conf.example" \
    > "$product/macos.conf.example"

ocvalidate="$REPO_ROOT/opencore/Utilities/ocvalidate.linux"
if "$ocvalidate" "$efi/OC/config.plist"; then
    :
else
    fail "OpenCore 1.0.6 rejected the rendered config.plist"
fi

if [[ "$make_image" == yes ]]; then
    mkdir -p -- "$work_root/esp-root"
    cp -R -- "$efi" "$work_root/esp-root/EFI"
    makefs -t msdos -s 64m "$work_root/opencore-esp.img" "$work_root/esp-root" >/dev/null
    mkimg -s gpt -p "efi:=$work_root/opencore-esp.img" -o "$product/opencore.img"
fi

archive_members=(
    BHYVE_UEFI.fd BHYVE_UEFI_VARS.fd EFI LICENSES NOTICE README-FIRST.txt
    identity.env macos.conf.example patches.plist
)
[[ "$make_image" == no ]] || archive_members+=(opencore.img)
tar -C "$product" -czf "$product/macos-amd-bhyve-ready.tar.gz" \
    "${archive_members[@]}"

(
    cd -- "$product"
    while IFS= read -r file; do
        printf '%s  %s\n' "$(file_sha256 "$file")" "$file"
    done < <(find . -type f ! -name SHA256SUMS -print | LC_ALL=C sort)
) > "$product/SHA256SUMS"

mv -- "$product" "$output_dir"
trap - EXIT HUP INT TERM
rm -rf -- "$work_root"

cat <<EOF
OpenCore bundle created at $output_dir
Private identity values are in $output_dir/identity.env (mode 0600).
Use NETWORK_MAC and VM_UUID from that file in the vm-bhyve configuration.
Before signing in to Apple services, verify that the generated serial is unused.
EOF
