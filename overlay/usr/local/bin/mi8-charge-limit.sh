#!/bin/sh
# mi8-charge-limit.sh — 插电时把电量维持在 60~80%（暂停输入电流，数据线不断）
#
# 关键点：内核 charger 驱动在 USB 重新协商 / 重新插拔时会把 current_max 恢复成
# 默认值（实测 1400000uA），所以不能靠"状态文件说已暂停"就跳过检查，
# 每次都要读实际 current_max 再决定是否重新写 0。
set -u

LIMIT=${LIMIT:-90}
RESUME=${RESUME:-85}
ST=/var/lib/mi8-charge-limit.state
CAP=/sys/class/power_supply/qcom-battery/capacity
ICM=/sys/class/power_supply/pmi8998-charger/current_max
DEFAULT=500000

[ -r "$CAP" ] || exit 0
[ -w "$ICM" ] || exit 0

cap=$(cat "$CAP" 2>/dev/null) || exit 0
[ -n "$cap" ] || exit 0

saved=$DEFAULT
[ -r "$ST" ] && . "$ST" 2>/dev/null || true

cur=$(cat "$ICM" 2>/dev/null || echo "")

if [ "$cap" -ge "$LIMIT" ]; then
    if [ -n "$cur" ] && [ "$cur" != "0" ] && [ "$cur" != "$saved" ]; then
        saved=$cur
        printf 'saved=%s\n' "$saved" > "$ST" 2>/dev/null || true
    fi
    if [ "$cur" != "0" ]; then
        if echo 0 > "$ICM" 2>/dev/null; then
            logger -t mi8-charge "cap=${cap}% >= ${LIMIT}% -> 暂停充电（保存 ${saved}uA）"
        fi
    fi
elif [ "$cap" -le "$RESUME" ]; then
    if [ "$cur" = "0" ]; then
        if echo "$saved" > "$ICM" 2>/dev/null; then
            logger -t mi8-charge "cap=${cap}% <= ${RESUME}% -> 恢复充电（${saved}uA）"
        fi
    fi
fi

exit 0
