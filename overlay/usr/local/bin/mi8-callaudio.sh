#!/bin/sh
# mi8-callaudio.sh start|stop
# Mi 8 (dipper) 通话音频。
# 下行: MultiMedia2(hw:0,1) -> SLIMBUS_0_RX -> AIF1_PB -> SLIM RX0 -> RX INT0 -> 听筒
# 上行: 底部麦 -> ADC3 -> DEC0 -> SLIM TX0 -> AIF1_CAP -> SLIMBUS_0_TX（CS-Voice 送 modem）
# 注：SLIMBUS_1_RX 在 ADSP 上起不来（AFE port 0x4002 -22），别用。
set -u
C=0
CARD=hw:0,1
SINK=voice_sink
SRC=voice_src

cs() { amixer -c "$C" cset "name='$1'" "$2" >/dev/null 2>&1 || true; }

unload() {
    for n in "$SINK" "$SRC"; do
        ids=$(pactl list short modules 2>/dev/null | awk -v n="$n" '$3==n{print $1}')
        for i in $ids; do pactl unload-module "$i" >/dev/null 2>&1 || true; done
    done
}

start() {
    # 下行 -> 听筒
    cs "SLIMBUS_0_RX Audio Mixer MultiMedia2" 1
    cs "SLIM RX0 MUX" AIF1_PB
    cs "RX INT0_1 MIX1 INP0" RX0
    cs "RX INT0 DEM MUX" CLSH_DSM_OUT
    cs "RX0 Digital Volume" 84

    # 上行 -> 语音
    cs "CS-Voice Capture Mixer SLIMBUS_0_TX" 1
    cs "MultiMedia2 Mixer SLIMBUS_0_TX" 1
    cs "AIF1_CAP Mixer SLIM TX0" 1
    cs "CDC_IF TX0 MUX" DEC0
    cs "ADC MUX0" AMIC
    cs "AMIC MUX0" ADC3
    cs "DEC0 Volume" 84
    cs "ADC3 Volume" 12

    if ! pactl list short sinks 2>/dev/null | grep -q "$SINK"; then
        pactl load-module module-alsa-sink device=$CARD sink_name=$SINK rate=8000 channels=1 tsched=0 >/dev/null 2>&1 \
        || pactl load-module module-alsa-sink device=$CARD sink_name=$SINK >/dev/null 2>&1 || true
    fi
    if ! pactl list short sources 2>/dev/null | grep -q "$SRC"; then
        pactl load-module module-alsa-source device=$CARD source_name=$SRC rate=8000 channels=1 tsched=0 >/dev/null 2>&1 \
        || pactl load-module module-alsa-source device=$CARD source_name=$SRC >/dev/null 2>&1 || true
    fi

    pactl set-default-sink $SINK >/dev/null 2>&1 || true
    pactl set-default-source $SRC >/dev/null 2>&1 || true
    logger -t mi8-call "voice call audio ON (SLIMBUS_0 + AIF1, earpiece + bottom mic)"
}

stop() {
    unload
    pactl set-default-sink alsa_output.platform-sound.HiFi__Speaker__sink >/dev/null 2>&1 || true
    pactl set-default-source mic_bottom >/dev/null 2>&1 || true

    cs "SLIMBUS_0_RX Audio Mixer MultiMedia2" 0
    cs "CS-Voice Capture Mixer SLIMBUS_0_TX" 0
    cs "MultiMedia2 Mixer SLIMBUS_0_TX" 0
    cs "RX INT0_1 MIX1 INP0" ZERO
    logger -t mi8-call "voice call audio OFF"
}

case "${1:-}" in
    start) start ;;
    stop)  stop ;;
    *) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac
