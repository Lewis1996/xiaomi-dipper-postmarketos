#!/bin/sh
# mi8-callaudio-watch.sh — 轮询 modem 通话状态，自动开关通话音频路由
# 注意：mmcli --voice-list-calls 的输出是
#     /org/freedesktop/ModemManager1/Call/8 outgoing (active)
# 状态在括号里，没有 "state:" 前缀，不能按 key: value 解析。
set -u
prev=""

while :; do
    st=$(mmcli -m 0 --voice-list-calls 2>/dev/null | grep -o '([a-z-]*)' | head -1 | tr -d '()')
    [ -z "$st" ] && st=none

    case "$st" in
        dialing|ringing-out|ringing-in|alerting|active|incoming|waiting|held) want=1 ;;
        *) want=0 ;;
    esac

    if [ "$want" != "$prev" ]; then
        if [ "$want" = 1 ]; then
            /usr/local/bin/mi8-callaudio.sh start
        else
            /usr/local/bin/mi8-callaudio.sh stop
        fi
        prev="$want"
    fi
    sleep 2
done
