#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_SOURCE_SHA256="a858e947ace143768e2a3b825d6fe97c8c7d7cafe79be2fc0dae844c35965264"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly SOURCE_FILE="$REPO_ROOT/acpi/SSDT-BHYVE-CPU.dsl"

usage() {
    echo "usage: $0 OUTPUT_DIRECTORY" >&2
}

if [[ ${1-} == "" ]]; then
    usage
    exit 64
fi

output_dir="$(mkdir -p -- "$1" && cd -- "$1" && pwd -P)"
command -v iasl >/dev/null || {
    echo "required command not found: iasl" >&2
    exit 127
}
if command -v sha256sum >/dev/null; then
    hash_file() { sha256sum "$1" | awk '{print $1}'; }
elif command -v sha256 >/dev/null; then
    hash_file() { sha256 -q "$1"; }
else
    echo "sha256sum or sha256 is required" >&2
    exit 127
fi

actual_source_sha256="$(hash_file "$SOURCE_FILE")"
if [[ "$actual_source_sha256" != "$EXPECTED_SOURCE_SHA256" ]]; then
    echo "SSDT source hash mismatch: expected $EXPECTED_SOURCE_SHA256, got $actual_source_sha256" >&2
    exit 1
fi

work_root="$(mktemp -d "${TMPDIR:-.}/dobby-ssdt-build.XXXXXXXX")"
cleanup() {
    rm -rf -- "$work_root"
}
trap cleanup EXIT

cp -- "$SOURCE_FILE" "$work_root/SSDT-BHYVE-CPU.dsl"
(
    cd -- "$work_root"
    iasl -tc SSDT-BHYVE-CPU.dsl
)

cp -- "$work_root/SSDT-BHYVE-CPU.aml" "$output_dir/SSDT-BHYVE-CPU.aml"
printf '%s  %s\n' "$(hash_file "$output_dir/SSDT-BHYVE-CPU.aml")" \
    "$output_dir/SSDT-BHYVE-CPU.aml"
