#!/bin/bash
# build.sh — one-command build for Xiaomi Mi 8 (dipper) postmarketOS
#
#   sudo ./scripts/build.sh
#
# Requires: pmbootstrap configured for device "xiaomi-dipper" (see docs/BUILD.md).
# Outputs:  out/boot.img    -> fastboot flash boot
#           out/rootfs.img  -> fastboot flash userdata
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$HERE/out}
DEVICE=${DEVICE:-xiaomi-dipper}
KPKG=linux-postmarketos-qcom-sdm845-dipper

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 0. sanity ----------
command -v pmbootstrap >/dev/null || die "pmbootstrap not installed (pip install pmbootstrap)"
APORTS=${APORTS:-$(pmbootstrap config aports 2>/dev/null || true)}
[ -d "${APORTS:-/nonexistent}" ] || die "pmaports not found. Run 'pmbootstrap init' first, or set APORTS=/path/to/pmaports"
[ -d "$HERE/overlay" ] || die "overlay/ missing — run from the repo root"
mkdir -p "$OUT"

log "0/6 environment"
echo "    repo:    $HERE"
echo "    pmaports:$APORTS"
echo "    device:  $DEVICE"
echo "    output:  $OUT"

# ---------- 1. packages ----------
log "1/6 installing kernel + device packages into pmaports"
cp -a "$HERE/pmaports/device/testing/." "$APORTS/device/testing/"

# ---------- 2. initramfs patch ----------
log "2/6 patching postmarketos-initramfs (10 s -> 1 s partition scan)"
if grep -q 'wait_seconds=1$' "$APORTS/main/postmarketos-initramfs/init_functions.sh" 2>/dev/null; then
    echo "    already patched"
else
    ( cd "$APORTS" && patch -p1 --forward < "$HERE/patches/postmarketos-initramfs-fast-partscan.patch" ) || true
    pmbootstrap checksum postmarketos-initramfs
fi

# ---------- 3-4. build ----------
log "3/6 building kernel package ($KPKG)"
pmbootstrap build "$KPKG"

log "4/6 building device package ($DEVICE)"
pmbootstrap build "device-$DEVICE"

# ---------- 5. image ----------
log "5/6 generating rootfs + boot images (this takes a while)"
pmbootstrap install --split

log "6/6 collecting images"
pmbootstrap export >/dev/null 2>&1 || true

BOOT=""
ROOTFS=""

# prefer the split images produced by 'install --split'
for d in "$HOME/.local/var/pmbootstrap"/chroot_native/home/pmos/rootfs \
         /root/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs; do
    [ -d "$d" ] || continue
    [ -z "$BOOT" ]   && BOOT=$(ls -t "$d"/*boot*.img 2>/dev/null | head -1 || true)
    [ -z "$ROOTFS" ] && ROOTFS=$(ls -t "$d"/*root*.img 2>/dev/null | head -1 || true)
done

# fall back to the export dir
EXP=/tmp/postmarketOS-export
if [ -z "$BOOT" ] && [ -f "$EXP/boot.img" ]; then BOOT="$EXP/boot.img"; fi
if [ -z "$ROOTFS" ] && [ -f "$EXP/$DEVICE-root.img" ]; then ROOTFS="$EXP/$DEVICE-root.img"; fi

[ -n "$BOOT" ]   || die "boot image not found; run 'pmbootstrap install --split' and check the output path"
[ -n "$ROOTFS" ] || die "rootfs image not found; run 'pmbootstrap install --split' and check the output path"

cp "$BOOT" "$OUT/boot.img"
cp "$ROOTFS" "$OUT/rootfs.img"

log "injecting rootfs overlay (UCM, services, scripts, firmware)"
"$HERE/scripts/apply-overlay.sh" "$OUT/rootfs.img"

log "done"
ls -la --time-style=long-iso "$OUT"/*.img
cat <<EOF

Flash with:
  fastboot flash boot     $OUT/boot.img
  fastboot flash userdata $OUT/rootfs.img      # this wipes user data
  fastboot reboot
EOF
