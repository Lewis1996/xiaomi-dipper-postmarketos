#!/bin/sh
# Keep the pmOS RNDIS gadget on the UDC.
#
# Failure modes covered:
#  1. initramfs/rootfs handoff leaves g1 unbound  -> rebind it
#  2. usb-signaller (or another gadget) grabs the UDC and replaces g1,
#     which silently kills USB networking -> unbind foreign gadgets first
#  3. configfs was unmounted/lost -> recreate the gadget
# Safe to run repeatedly; it exits immediately when g1 already owns the UDC.
set -u
LOG=/run/usb-gadget-fixup.log
G=/sys/kernel/config/usb_gadget/g1
CFG=/sys/kernel/config
UDC_NAME=$(ls /sys/class/udc 2>/dev/null | head -1)

log() { echo "$(date -u +%H:%M:%S) $*" >>"$LOG"; }

[ -n "${UDC_NAME:-}" ] || exit 0
mountpoint -q "$CFG" || mount -t configfs none "$CFG" 2>/dev/null

# 1. if a foreign gadget owns the UDC, release it
for d in "$CFG"/usb_gadget/*/; do
	[ -d "$d" ] || continue
	[ "$d" = "$G/" ] && continue
	if [ -n "$(cat "$d/UDC" 2>/dev/null)" ]; then
		log "releasing foreign gadget $(basename "$d")"
		echo "" > "$d/UDC" 2>/dev/null
	fi
done

# 1b. bound but with the WRONG function: usb-moded/usb-signaller reuses the
#     same g1 gadget and may leave it with ncm/adb only, which Windows cannot
#     use as a NIC.  Only "bound + rndis linked" counts as healthy.
have_rndis=no
[ -e "$G/configs/c.1/rndis.usb0" ] && have_rndis=yes

if [ -d "$G" ] && [ "$(cat "$G/UDC" 2>/dev/null)" = "$UDC_NAME" ] && [ "$have_rndis" = yes ]; then
	ip link set usb0 up 2>/dev/null
	ip addr add 172.16.42.1/24 dev usb0 2>/dev/null
	exit 0
fi

if [ -d "$G" ] && [ "$have_rndis" = no ]; then
	log "g1 bound without rndis (has: $(ls "$G/configs/c.1" 2>/dev/null | tr '
' ' ')), rebuilding"
fi

log "g1 dir=$([ -d $G ] && echo yes || echo no) bound=[$(cat "$G/UDC" 2>/dev/null)]"
modprobe -a libcomposite usb_f_rndis u_ether 2>/dev/null

if [ ! -d "$G" ]; then
	log "creating rndis gadget"
	mkdir -p "$G" || { log "mkdir gadget failed"; exit 1; }
	echo 0x1d6b > "$G/idVendor"
	echo 0x0104 > "$G/idProduct"
	echo "postmarketOS" > "$G/strings/0x409/manufacturer"
	echo "Xiaomi Mi 8" > "$G/strings/0x409/product"
	echo "0123456789" > "$G/strings/0x409/serialnumber"
	mkdir -p "$G/configs/c.1/strings/0x409"
	echo "rndis" > "$G/configs/c.1/strings/0x409/configuration"
	mkdir -p "$G/functions/rndis.usb0" || log "mkdir rndis function failed"
fi

echo "" > "$G/UDC" 2>/dev/null
sleep 1
# drop any foreign function links usb-moded left behind
for l in "$G"/configs/c.1/*; do
	[ -L "$l" ] || continue
	case "$(basename "$l")" in
	rndis.usb0) ;;
	*) log "unlinking foreign function $(basename "$l")"; rm -f "$l" ;;
	esac
done
ln -sf "$G/functions/rndis.usb0" "$G/configs/c.1/" 2>/dev/null
if echo "$UDC_NAME" > "$G/UDC" 2>/dev/null; then
	log "bound $UDC_NAME"
else
	log "bind failed"
	dmesg | tail -6 >>"$LOG"
fi
sleep 2
ip link set usb0 up 2>/dev/null
ip addr add 172.16.42.1/24 dev usb0 2>/dev/null
log "done udc=[$(cat "$G/UDC" 2>/dev/null)] usb0=$(ip -4 -o addr show usb0 2>/dev/null | awk '{print $4}')"
