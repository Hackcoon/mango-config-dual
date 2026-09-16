#!/usr/bin/env bash
# to-dms.sh — switch the mango session from Noctalia back to DMS.
# Steps: stop noctalia -> wait dead -> start DMS -> wait IPC -> flip keymode.
# Any step failing rolls back to Noctalia (noctalia keymode) and exits nonzero.
set -u
NOCTALIA=/home/fury/.nix-profile/bin/noctalia

rollback() {
    # Do not leave both layer-shell daemons alive if DMS started but failed
    # its IPC check.
    systemctl --user stop dms >/dev/null 2>&1 || true
    systemctl --user start noctalia >/dev/null 2>&1 || true
    mmsg dispatch "setkeymode,noctalia" >/dev/null 2>&1 || true
    echo "to-dms: FAILED at: $1 — rolled back to Noctalia" >&2
    exit 1
}

systemctl --user stop noctalia >/dev/null 2>&1 || true
for _ in $(seq 1 100); do
    [ "$(systemctl --user is-active noctalia 2>/dev/null)" = "inactive" ] && break
    sleep 0.1
    [ "$_" = "100" ] && rollback "noctalia did not stop"
done

systemctl --user start dms >/dev/null 2>&1 \
    || rollback "dms service failed to start"

# dms CLI talks once the backend is up (same probe toggle-dms-bar.sh uses).
for _ in $(seq 1 300); do
    dms ipc call settings dump >/dev/null 2>&1 && break
    sleep 0.1
    [ "$_" = "300" ] && rollback "dms IPC never came up"
done

mmsg dispatch "setkeymode,default" >/dev/null 2>&1 \
    || rollback "keymode flip failed"

notify-send 'Shell switched' 'DMS is active (SUPER+ALT+N for Noctalia)' >/dev/null 2>&1 || true
echo "to-dms: OK"
