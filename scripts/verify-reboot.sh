#!/bin/sh
set -eu

VM_NAME=${VM_NAME:-macos-amd-bhyve}
DATASTORE=${DATASTORE:-}
SSH_USER=${SSH_USER:-}
SSH_HOST=${SSH_HOST:-}
SSH_KEY=${SSH_KEY:-}
SSH_KNOWN_HOSTS=${SSH_KNOWN_HOSTS:-}

if [ "${1:-}" != "--apply" ]; then
    echo "reboot proof is mutation-bearing; pass --apply after review" >&2
    exit 2
fi
for value in DATASTORE SSH_USER SSH_HOST SSH_KEY SSH_KNOWN_HOSTS; do
    eval "present=\${$value:-}"
    [ -n "$present" ] || { echo "$value is required" >&2; exit 2; }
done

probe() {
    # Keep the guest probe free of private addresses and credentials.
    ssh -o BatchMode=yes -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=yes \
        -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" -i "$SSH_KEY" \
        "$SSH_USER@$SSH_HOST" \
        'sw_vers -productVersion; sw_vers -buildVersion; uname -m; sysctl -n hw.ncpu; ifconfig en0; route -n get default'
}

if ! probe; then
    vm start "$VM_NAME"
    i=0
    while ! probe >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -lt 90 ] || { echo "guest did not become reachable" >&2; exit 1; }
        sleep 2
    done
fi
probe
ssh -o BatchMode=yes -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$SSH_KNOWN_HOSTS" -i "$SSH_KEY" \
    "$SSH_USER@$SSH_HOST" 'sudo -n shutdown -r now'
i=0
while probe >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -lt 60 ] || { echo "guest did not leave SSH after reboot request" >&2; exit 1; }
    sleep 2
done
i=0
while ! probe >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -lt 120 ] || { echo "guest did not return after reboot" >&2; exit 1; }
    sleep 2
done
probe
echo "reboot persistence proof passed"
