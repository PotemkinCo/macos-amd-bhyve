#!/bin/sh
set -eu

VM_NAME=${VM_NAME:-macos-amd-bhyve}
DATASTORE=${DATASTORE:-}
BACKUP_DIR=${BACKUP_DIR:-}

if [ "${1:-}" != "--apply" ]; then
    echo "usage: DATASTORE=/path BACKUP_DIR=/path $0 --apply" >&2
    exit 2
fi
[ -n "$DATASTORE" ] || { echo "DATASTORE is required" >&2; exit 2; }
[ -n "$BACKUP_DIR" ] || { echo "BACKUP_DIR is required" >&2; exit 2; }
[ -d "$BACKUP_DIR" ] || { echo "backup directory not found" >&2; exit 2; }
if command -v vm >/dev/null 2>&1 && vm info "$VM_NAME" 2>/dev/null | grep -Eiq 'running|active'; then
    echo "refusing rollback while VM is running" >&2
    exit 1
fi

vm_root="$DATASTORE/$VM_NAME"
[ -d "$vm_root" ] || { echo "VM directory not found" >&2; exit 2; }
for name in BHYVE_UEFI.fd "$VM_NAME.conf" SSDT-BHYVE-CPU.aml; do
    if [ -f "$BACKUP_DIR/$name" ]; then
        case "$name" in
            BHYVE_UEFI.fd) install -m 600 "$BACKUP_DIR/$name" "$DATASTORE/.config/$name" ;;
            *) install -m 600 "$BACKUP_DIR/$name" "$vm_root/$name" ;;
        esac
    fi
done
echo "rollback complete; no guest disk or UEFI variable was removed"
