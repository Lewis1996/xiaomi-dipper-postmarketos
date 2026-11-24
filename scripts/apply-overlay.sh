#!/bin/bash
# apply-overlay.sh — inject overlay/ into a postmarketOS rootfs image
#
#   ./scripts/apply-overlay.sh rootfs.img
#
# Idempotent: safe to run twice. Requires root (loop mount).
set -euo pipefail

SRC=${1:?usage: apply-overlay.sh <rootfs.img>}
HERE=$(cd "$(dirname "$0")" && pwd)
if [ -d "$HERE/overlay" ]; then
    OV=$HERE/overlay
elif [ -d "$HERE/../overlay" ]; then
    OV=$(cd "$HERE/../overlay" && pwd)
else
    echo "overlay/ not found next to this script" >&2
    exit 1
fi

M=$(mktemp -d /tmp/mi8ov.XXXXXX)
cleanup() { umount "$M" 2>/dev/null || true; rmdir "$M" 2>/dev/null || true; }
trap cleanup EXIT

echo "== mounting $SRC"
mount -o loop "$SRC" "$M"

echo "== copying overlay"
# /lib is a symlink to usr/lib in the image: copy it separately
tar -C "$OV" -cf - --exclude=./lib . | tar -C "$M" -xf -
if [ -d "$OV/lib/firmware" ]; then
    mkdir -p "$M/usr/lib/firmware"
    cp -a "$OV/lib/firmware/." "$M/usr/lib/firmware/"
fi

echo "== enabling system units"
SYS=$M/etc/systemd/system
mkdir -p "$SYS/multi-user.target.wants" "$SYS/timers.target.wants"
for u in mi8-telnetd.service mi8-diag-push.service mi8-charge-limit.service \
         mi8-mic-route.service mi8-firstboot.service; do
    [ -f "$SYS/$u" ] && ln -sf "/etc/systemd/system/$u" "$SYS/multi-user.target.wants/$u"
done
for t in mi8-charge-limit.timer usb-gadget-fixup.timer; do
    [ -f "$SYS/$t" ] && ln -sf "/etc/systemd/system/$t" "$SYS/timers.target.wants/$t"
done

echo "== masking usb-signaller (keeps RNDIS visible to Windows)"
for u in usb-signaller.service usb-signaller-developer-mode.service \
         usb-signaller-mtp-mode.service usb-signaller-tethering-mode.service; do
    ln -sf /dev/null "$SYS/$u"
done

echo "== enabling user units"
UD=$M/home/user/.config/systemd/user
mkdir -p "$UD/graphical-session.target.wants" "$UD/default.target.wants"
for u in mi8-ambient.service mi8-osk.service mi8-im.service mi8-callaudio.service \
         mi8-power.service; do
    [ -f "$UD/$u" ] && ln -sf "/home/user/.config/systemd/user/$u" "$UD/graphical-session.target.wants/$u"
done
[ -f "$UD/mi8-callaudio.service" ] && ln -sf "/home/user/.config/systemd/user/mi8-callaudio.service" "$UD/default.target.wants/mi8-callaudio.service"

echo "== permissions"
chown -R 10000:10000 "$M/home/user/.config" 2>/dev/null || true
chown 10000:0 "$M/home/user" 2>/dev/null || true
chmod 755 "$M"/usr/local/bin/mi8-*.sh 2>/dev/null || true
chmod 755 "$M"/usr/lib/systemd/system-sleep/* 2>/dev/null || true
chmod 644 "$M"/etc/pulse/default.pa.d/*.pa 2>/dev/null || true

echo "== verify"
test -f "$M/usr/share/alsa/ucm2/Xiaomi/dipper/HiFi.conf" && echo "  ok UCM"
test -f "$M/usr/lib/firmware/tas2557_uCDSP.bin"        && echo "  ok tas2557 firmware"
test -f "$M/etc/gdm/custom.conf"                       && echo "  ok gdm autologin"
test -f "$M/usr/lib/systemd/system-sleep/mi8-touch-resume" && echo "  ok resume hook"
test -f "$M/usr/share/q6voiced/q6voiced.conf"          && echo "  ok q6voiced config"

sync
umount "$M"
trap - EXIT
rmdir "$M" 2>/dev/null || true
echo DONE
