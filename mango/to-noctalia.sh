#!/usr/bin/env bash
# to-noctalia.sh — switch the mango session from DMS to Noctalia.
# Steps: stop DMS -> wait dead -> start noctalia -> wait IPC -> flip keymode.
# Any step failing rolls back to DMS (default keymode) and exits nonzero.
set -u
NOCTALIA=/home/fury/.nix-profile/bin/noctalia

rollback() {
    # Do not leave both layer-shell daemons alive if Noctalia started but
    # failed its IPC check.
    systemctl --user stop noctalia >/dev/null 2>&1 || true
    systemctl --user start dms >/dev/null 2>&1 || true
    mmsg dispatch "setkeymode,default" >/dev/null 2>&1 || true
    echo "to-noctalia: FAILED at: $1 — rolled back to DMS" >&2
    exit 1
}

systemctl --user stop dms >/dev/null 2>&1 || true
for _ in $(seq 1 100); do
    [ "$(systemctl --user is-active dms 2>/dev/null)" = "inactive" ] && break
    sleep 0.1
    [ "$_" = "100" ] && rollback "dms did not stop"
done

systemctl --user start noctalia >/dev/null 2>&1 \
    || rollback "noctalia service failed to start"

for _ in $(seq 1 300); do
    "$NOCTALIA" msg status >/dev/null 2>&1 && break
    sleep 0.1
    [ "$_" = "300" ] && rollback "noctalia IPC never came up"
done

mmsg dispatch "setkeymode,noctalia" >/dev/null 2>&1 \
    || rollback "keymode flip failed"

"$NOCTALIA" msg notification-show "Shell switched" "Noctalia is active (SUPER+ALT+D returns to DMS)" >/dev/null 2>&1 || true
echo "to-noctalia: OK"
