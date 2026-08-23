#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VM_NAME=${VM_NAME:-macos-amd-bhyve}
DATASTORE=${DATASTORE:-}
CUSTOM_FIRMWARE=${CUSTOM_FIRMWARE:-}
VM_CONFIG=${VM_CONFIG:-"$ROOT/config/vm.conf.example"}
OPENCORE_IMAGE=${OPENCORE_IMAGE:-}
SSDT_AML=${SSDT_AML:-"$ROOT/work/ssdt/SSDT-BHYVE-CPU.aml"}

if [ "${1:-}" != "--apply" ]; then
    echo "dry-run only; pass --apply after reviewing the owner-supplied paths" >&2
    exit 2
fi
[ -n "$DATASTORE" ] || { echo "DATASTORE is required" >&2; exit 2; }
[ -n "$CUSTOM_FIRMWARE" ] || { echo "CUSTOM_FIRMWARE is required" >&2; exit 2; }
[ -f "$CUSTOM_FIRMWARE" ] && [ ! -L "$CUSTOM_FIRMWARE" ] || { echo "custom firmware must be a regular file" >&2; exit 2; }
[ -f "$VM_CONFIG" ] || { echo "VM_CONFIG is missing: $VM_CONFIG" >&2; exit 2; }
[ -f "$SSDT_AML" ] || { echo "SSDT_AML is missing: $SSDT_AML" >&2; exit 2; }
[ -d "$DATASTORE/.config" ] || { echo "DATASTORE/.config must already exist" >&2; exit 2; }

if command -v vm >/dev/null 2>&1 && vm info "$VM_NAME" 2>/dev/null | grep -Eiq 'running|active'; then
    echo "refusing install while VM is running" >&2
    exit 1
fi

vm_root="$DATASTORE/$VM_NAME"
mkdir -p "$vm_root/backups"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="$vm_root/backups/$stamp"
mkdir -p "$backup"

if [ -f "$DATASTORE/.config/BHYVE_UEFI.fd" ]; then
    install -m 600 "$DATASTORE/.config/BHYVE_UEFI.fd" "$backup/BHYVE_UEFI.fd"
fi
if [ -f "$vm_root/$VM_NAME.conf" ]; then
    install -m 600 "$vm_root/$VM_NAME.conf" "$backup/$VM_NAME.conf"
fi
if [ -f "$vm_root/SSDT-BHYVE-CPU.aml" ]; then
    install -m 600 "$vm_root/SSDT-BHYVE-CPU.aml" "$backup/SSDT-BHYVE-CPU.aml"
fi

install -m 600 "$CUSTOM_FIRMWARE" "$DATASTORE/.config/BHYVE_UEFI.fd"
install -m 600 "$VM_CONFIG" "$vm_root/$VM_NAME.conf"
install -m 600 "$SSDT_AML" "$vm_root/SSDT-BHYVE-CPU.aml"
if [ -n "$OPENCORE_IMAGE" ]; then
    [ -f "$OPENCORE_IMAGE" ] && [ ! -L "$OPENCORE_IMAGE" ] || { echo "OPENCORE_IMAGE must be a regular file" >&2; exit 2; }
    install -m 600 "$OPENCORE_IMAGE" "$vm_root/$(basename "$OPENCORE_IMAGE")"
fi

printf 'BACKUP_DIR=%s\n' "$backup"
printf 'FIRMWARE_SHA256=%s\n' "$(sha256 -q "$DATASTORE/.config/BHYVE_UEFI.fd")"
printf 'CONFIG_SHA256=%s\n' "$(sha256 -q "$vm_root/$VM_NAME.conf")"
printf 'SSDT_SHA256=%s\n' "$(sha256 -q "$vm_root/SSDT-BHYVE-CPU.aml")"
echo "install complete; review vm.conf and run verify-install.sh before start"
