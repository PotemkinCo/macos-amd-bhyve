#!/bin/sh
set -eu

VM_NAME=${VM_NAME:-macos-amd-bhyve}
DATASTORE=${DATASTORE:-}
[ -n "$DATASTORE" ] || { echo "DATASTORE is required" >&2; exit 2; }
vm_root="$DATASTORE/$VM_NAME"
firmware="$DATASTORE/.config/BHYVE_UEFI.fd"
config="$vm_root/$VM_NAME.conf"
ssdt="$vm_root/SSDT-BHYVE-CPU.aml"

for path in "$firmware" "$config" "$ssdt"; do
    [ -f "$path" ] && [ ! -L "$path" ] || { echo "missing or symlinked: $path" >&2; exit 1; }
done
if grep -n 'REPLACE_' "$config"; then
    echo "working VM config still contains placeholders" >&2
    exit 1
fi
printf 'FIRMWARE_SHA256=%s\n' "$(sha256 -q "$firmware")"
printf 'CONFIG_SHA256=%s\n' "$(sha256 -q "$config")"
printf 'SSDT_SHA256=%s\n' "$(sha256 -q "$ssdt")"
if command -v vm >/dev/null 2>&1; then
    vm info "$VM_NAME"
fi
echo "host-side install checks passed; guest boot and persistence still require verify-reboot.sh"
