#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
EDK2_ROOT=${EDK2_ROOT:-}
PATCH=${EDK2_PATCH:-"$ROOT/patches/edk2-known-good-baseline-dxe.patch"}
OUT=${EDK2_OUTPUT_DIR:-"$ROOT/work/edk2-output"}
PIN=d46aa46c8361194521391aa581593e556c707c6e

if [ "${1:-}" != "--apply" ]; then
    echo "usage: EDK2_ROOT=/path/to/clean/edk2 $0 --apply" >&2
    exit 2
fi
[ -n "$EDK2_ROOT" ] || { echo "EDK2_ROOT is required" >&2; exit 2; }
[ -d "$EDK2_ROOT/.git" ] || { echo "EDK2_ROOT must be a Git checkout" >&2; exit 2; }
[ -f "$PATCH" ] || { echo "patch not found: $PATCH" >&2; exit 2; }

actual=$(git -C "$EDK2_ROOT" rev-parse HEAD)
[ "$actual" = "$PIN" ] || {
    echo "EDK2 commit mismatch: expected $PIN, got $actual" >&2
    exit 1
}
[ -z "$(git -C "$EDK2_ROOT" status --porcelain)" ] || {
    echo "EDK2 checkout must be clean before applying the baseline patch" >&2
    exit 1
}
submodules=$(git -C "$EDK2_ROOT" submodule status --recursive)
if printf '%s\n' "$submodules" | grep -Eq '^[+-U]'; then
    echo "EDK2 recursive submodules are not a clean pinned closure" >&2
    exit 1
fi

mkdir -p "$OUT"
git -C "$EDK2_ROOT" apply --check "$PATCH"
git -C "$EDK2_ROOT" apply --whitespace=nowarn "$PATCH"
git -C "$EDK2_ROOT" diff --check

cd "$EDK2_ROOT"
. ./edksetup.sh
make -C BaseTools
build -a X64 -b RELEASE -t GCC5 -p OvmfPkg/Bhyve/BhyveX64.dsc

firmware="$EDK2_ROOT/Build/BhyveX64/RELEASE_GCC5/FV/BHYVE_CODE.fd"
[ -f "$firmware" ] || { echo "BHYVE_CODE.fd was not produced" >&2; exit 1; }
install -m 600 "$firmware" "$OUT/BHYVE_CODE.fd"
sha=$(sha256 -q "$OUT/BHYVE_CODE.fd")
printf 'EDK2_COMMIT=%s\n' "$PIN" > "$OUT/provenance.txt"
printf 'EDK2_PATCH_SHA256=%s\n' "$(sha256 -q "$PATCH")" >> "$OUT/provenance.txt"
printf 'BHYVE_CODE_SHA256=%s\n' "$sha" >> "$OUT/provenance.txt"
printf 'BHYVE_CODE=%s\n' "$OUT/BHYVE_CODE.fd"
printf 'BHYVE_CODE_SHA256=%s\n' "$sha"
