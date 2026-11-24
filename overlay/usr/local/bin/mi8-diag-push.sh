#!/bin/sh
sleep 45
{
  echo "=== uname ==="; uname -a
  echo "=== services ==="; systemctl is-active hexagonrpcd-sdsp iio-sensor-proxy mi8-telnetd 2>&1
  echo "=== iio devices ==="; ls /sys/bus/iio/devices 2>&1
  echo "=== input devices ==="; for d in /sys/class/input/event*; do echo "$d $(cat $d/device/name 2>/dev/null)"; done
  echo "=== monitor-sensor 6s ==="; timeout 6 monitor-sensor 2>&1 | head -50
  echo "=== dmesg stmfts/touch ==="; dmesg 2>/dev/null | grep -iE 'stmfts|fts|touch|CONTROL_READY' | tail -40
  echo "=== persist mount ==="; mount | grep -i persist 2>&1
  echo "=== journal tail ==="; journalctl -b --no-pager 2>/dev/null | tail -200
  echo "=== END ==="
} > /tmp/mi8-diag.txt 2>&1
for ip in 172.16.42.2 172.16.42.3; do
  nc -w 8 $ip 9999 < /tmp/mi8-diag.txt 2>/dev/null && break
done
