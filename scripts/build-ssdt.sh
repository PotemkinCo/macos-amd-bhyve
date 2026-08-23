#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${SSDT_OUTPUT_DIR:-"$ROOT/work/ssdt"}
EXPECTED_SHA256=67174f18544899ce31f38b02cc6fc39bec7e38584ffbc351561fa59b52faee36

command -v iasl >/dev/null 2>&1 || {
    echo "iasl is required (install acpica-tools on the owner FreeBSD host)" >&2
    exit 2
}
mkdir -p "$OUT"
iasl -tc -p "$OUT/SSDT-BHYVE-CPU" "$ROOT/acpi/SSDT-BHYVE-CPU.dsl"
test -f "$OUT/SSDT-BHYVE-CPU.aml"
actual=$(sha256 -q "$OUT/SSDT-BHYVE-CPU.aml")
printf 'SSDT_AML=%s\n' "$OUT/SSDT-BHYVE-CPU.aml"
printf 'SSDT_SHA256=%s\n' "$actual"
if [ "$actual" != "$EXPECTED_SHA256" ]; then
    echo "SSDT digest differs from the preserved reference; inspect iasl/toolchain provenance" >&2
    exit 1
fi
