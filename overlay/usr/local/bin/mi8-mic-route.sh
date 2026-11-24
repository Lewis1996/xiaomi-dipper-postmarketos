#!/bin/sh
# mi8-mic-route.sh — 建立 WCD9340 底部麦克风采集链路
# AMIC -> ADC3 -> DEC0 -> CDC_IF TX0 -> SLIM TX0 -> MultiMedia3 (hw:0,2)
# PulseAudio 探测 hw:0,2 前必须先把这个路由打开，否则 open 失败、音源被丢弃。
set -u
C=0
cset() {
    amixer -c "$C" cset "name='$1'" "$2" >/dev/null 2>&1 || true
}

cset "MultiMedia3 Mixer SLIMBUS_0_TX" 1
cset "AIF1_CAP Mixer SLIM TX0" 1
cset "CDC_IF TX0 MUX" DEC0
cset "ADC MUX0" AMIC
cset "DEC0 Volume" 84
cset "AMIC MUX0" ADC3
cset "ADC3 Volume" 12

logger -t mi8-mic "capture route applied (AMIC->ADC3->DEC0->SLIM TX0->MM3)"
exit 0
