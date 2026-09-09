#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_COMMIT="d46aa46c8361194521391aa581593e556c707c6e"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly PATCH_FILE="$REPO_ROOT/patches/edk2/0001-bhyve-filebuffer-image-verification.patch"

usage() {
    echo "usage: $0 CLEAN_EDK2_CHECKOUT OUTPUT_DIRECTORY" >&2
    echo "The checkout must already exist at the pinned commit and be clean." >&2
}

if [[ ${1-} == "" || ${2-} == "" ]]; then
    usage
    exit 64
fi

source_dir="$(cd -- "$1" && pwd -P)"
output_dir="$(mkdir -p -- "$2" && cd -- "$2" && pwd -P)"

for command_name in git patch python3; do
    command -v "$command_name" >/dev/null || {
        echo "required command not found: $command_name" >&2
        exit 127
    }
done

if command -v gmake >/dev/null; then
    make_command="gmake"
elif make --version 2>/dev/null | grep -q 'GNU Make'; then
    make_command="make"
else
    echo "GNU make is required (gmake on FreeBSD)" >&2
    exit 127
fi
if ! command -v sha256sum >/dev/null && ! command -v sha256 >/dev/null; then
    echo "sha256sum or sha256 is required" >&2
    exit 127
fi

actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_commit" != "$EXPECTED_COMMIT" ]]; then
    echo "EDK2 commit mismatch: expected $EXPECTED_COMMIT, got $actual_commit" >&2
    exit 1
fi

if [[ -n "$(git -C "$source_dir" status --porcelain --untracked-files=all)" ]]; then
    echo "EDK2 checkout is not clean" >&2
    exit 1
fi

while IFS= read -r submodule_state; do
    case "$submodule_state" in
        -*|+*|U*)
            echo "EDK2 recursive submodule is not clean or initialized: $submodule_state" >&2
            exit 1
            ;;
    esac
done < <(git -C "$source_dir" submodule status --recursive)

if [[ "$output_dir" == "$source_dir" || "$output_dir" == "$source_dir"/* ]]; then
    echo "output directory must be outside the EDK2 checkout" >&2
    exit 1
fi

work_root="$(mktemp -d "${TMPDIR:-.}/dobby-edk2-build.XXXXXXXX")"
cleanup() {
    rm -rf -- "$work_root"
}
trap cleanup EXIT

mkdir -p -- "$work_root/edk2"
cp -a -- "$source_dir/." "$work_root/edk2/"
patch --batch --forward --strip=1 --input="$PATCH_FILE" --directory="$work_root/edk2"

(
    cd -- "$work_root/edk2"
    "$make_command" -C BaseTools
    source edksetup.sh
    build -a X64 -b RELEASE -t GCC5 -p OvmfPkg/Bhyve/BhyveX64.dsc
)

firmware_dir="$work_root/edk2/Build/BhyveX64/RELEASE_GCC5/FV"
code_firmware="$firmware_dir/BHYVE_CODE.fd"
vars_firmware="$firmware_dir/BHYVE_VARS.fd"
if [[ ! -f "$code_firmware" ]]; then
    echo "EDK2 build did not produce $code_firmware" >&2
    exit 1
fi
if [[ ! -f "$vars_firmware" ]]; then
    echo "EDK2 build did not produce $vars_firmware" >&2
    exit 1
fi

cp -- "$code_firmware" "$output_dir/BHYVE_CODE.fd"
cp -- "$code_firmware" "$output_dir/BHYVE_UEFI.fd"
cp -- "$vars_firmware" "$output_dir/BHYVE_UEFI_VARS.fd"
for output in BHYVE_CODE.fd BHYVE_UEFI.fd BHYVE_UEFI_VARS.fd; do
    if command -v sha256sum >/dev/null; then
        sha256sum "$output_dir/$output"
    else
        sha256 "$output_dir/$output"
    fi
done
