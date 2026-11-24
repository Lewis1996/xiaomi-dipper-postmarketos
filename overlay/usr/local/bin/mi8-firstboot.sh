#!/bin/sh
# mi8-firstboot.sh — 首次开机把离线 apk（输入法等）装上，然后自我禁用
set -u
D=/usr/share/mi8-fixes/apks
STAMP=/var/lib/mi8-firstboot.done
[ -f "$STAMP" ] && exit 0

if [ -d "$D" ] && ls "$D"/*.apk >/dev/null 2>&1; then
    apk add --no-network --allow-untrusted "$D"/*.apk 2>&1 | tail -3
fi

mkdir -p /var/lib && : > "$STAMP"
systemctl disable mi8-firstboot.service >/dev/null 2>&1 || true
logger -t mi8-firstboot "offline apks installed"
exit 0
