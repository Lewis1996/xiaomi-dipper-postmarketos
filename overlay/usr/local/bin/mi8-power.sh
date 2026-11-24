#!/bin/sh
# mi8-power.sh — 首次登录时设置电源策略：空闲 10 分钟自动挂起（s2idle）
# 只在没有 marker 时执行，之后用户在「设置 → 电源」里改过就不会被覆盖。
set -u
MARK="${HOME:-/home/user}/.local/state/mi8-power.applied"
[ -f "$MARK" ] && exit 0

g() { gsettings set org.gnome.settings-daemon.plugins.power "$1" "$2" 2>/dev/null || true; }

g sleep-inactive-ac-type 'suspend'
g sleep-inactive-battery-type 'suspend'
g sleep-inactive-ac-timeout 600
g sleep-inactive-battery-timeout 600

mkdir -p "$(dirname "$MARK")" 2>/dev/null
: > "$MARK" 2>/dev/null || true
logger -t mi8-power "auto-suspend policy applied (600s)"
exit 0
