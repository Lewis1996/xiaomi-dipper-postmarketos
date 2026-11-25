#!/bin/bash
# apply-overlay.sh — 把 overlay/ 里的全部修复应用到一张 rootfs 镜像上
# 用法: ./apply-overlay.sh <rootfs.img> [输出镜像路径]
set -euo pipefail

SRC=${1:?用法: apply-overlay.sh <rootfs.img> [out.img]}
OUT=${2:-}
HERE=$(cd "$(dirname "$0")" && pwd)
OV=$HERE/overlay
M=$(mktemp -d /tmp/mi8ov.XXXXXX)

[ -d "$OV" ] || { echo "缺少 overlay 目录"; exit 1; }

cleanup() { umount "$M" 2>/dev/null || true; rmdir "$M" 2>/dev/null || true; }
trap cleanup EXIT

echo "== 挂载 $SRC =="
mount -o loop "$SRC" "$M"

echo "== 复制文件 =="
# /lib 在镜像里是 -> usr/lib 的软链，直接 cp 会报错，先排除再单独落到 usr/lib
tar -C "$OV" -cf - --exclude=./lib . | tar -C "$M" -xf -
if [ -d "$OV/lib/firmware" ]; then
    mkdir -p "$M/usr/lib/firmware"
    cp -a "$OV/lib/firmware/." "$M/usr/lib/firmware/"
fi

echo "== 系统级 enable 链接 =="
SYS=$M/etc/systemd/system
mkdir -p "$SYS/multi-user.target.wants" "$SYS/timers.target.wants"
for u in mi8-telnetd.service mi8-charge-limit.service mi8-mic-route.service mi8-firstboot.service mi8-resize-root.service; do
    [ -f "$SYS/$u" ] && ln -sf "/etc/systemd/system/$u" "$SYS/multi-user.target.wants/$u"
done
for t in mi8-charge-limit.timer usb-gadget-fixup.timer; do
    [ -f "$SYS/$t" ] && ln -sf "/etc/systemd/system/$t" "$SYS/timers.target.wants/$t"
done

echo "== 屏蔽 usb-signaller（否则 Windows 看不到 RNDIS）=="
for u in usb-signaller.service usb-signaller-developer-mode.service \
         usb-signaller-mtp-mode.service usb-signaller-tethering-mode.service; do
    ln -sf /dev/null "$SYS/$u"
done

echo "== 用户级 enable 链接 =="
UD=$M/home/user/.config/systemd/user
mkdir -p "$UD/graphical-session.target.wants" "$UD/default.target.wants"
for u in mi8-ambient.service mi8-osk.service mi8-im.service mi8-callaudio.service mi8-power.service; do
    [ -f "$UD/$u" ] && ln -sf "/home/user/.config/systemd/user/$u" "$UD/graphical-session.target.wants/$u"
done
[ -f "$UD/mi8-callaudio.service" ] && ln -sf "/home/user/.config/systemd/user/mi8-callaudio.service" "$UD/default.target.wants/mi8-callaudio.service"

echo "== 属主/权限 =="
chown -R 10000:10000 "$M/home/user/.config" 2>/dev/null || true
chown 10000:0 "$M/home/user" 2>/dev/null || true
chmod 755 "$M"/usr/local/bin/mi8-*.sh 2>/dev/null || true
chmod 644 "$M"/etc/pulse/default.pa.d/*.pa 2>/dev/null || true

echo "== 校验 =="
test -f "$M/usr/local/bin/mi8-charge-limit.sh" && echo "  ok charge-limit"
test -f "$M/usr/share/alsa/ucm2/Xiaomi/dipper/HiFi.conf" && echo "  ok UCM"
test -f "$M/lib/firmware/tas2557_uCDSP.bin" && echo "  ok tas2557 firmware"
test -f "$M/etc/gdm/custom.conf" && echo "  ok gdm autologin"
ls "$M/usr/share/mi8-fixes/apks"/*.apk >/dev/null 2>&1 && echo "  ok offline apks"

sync
umount "$M"
trap - EXIT
rmdir "$M" 2>/dev/null || true

if [ -n "$OUT" ]; then
    echo "== 输出 $OUT =="
    cp "$SRC" "$OUT"
fi
echo DONE
