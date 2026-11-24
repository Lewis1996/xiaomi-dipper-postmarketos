# Port status — what was fixed and where

Kernel: `linux-postmarketos-qcom-sdm845-dipper` **7.1_rc1-r109**
Device: `device-xiaomi-dipper`
Rootfs: `overlay/`

## Kernel package

### `sdm845-xiaomi-dipper.dts`

| Area | Change |
|---|---|
| Panel | `samsung,ea8074` compatible, DSI command mode, no WLED backlight (DCS 0x51 brightness) |
| Touch | `st,stmfts5` on `i2c14 @ 0x49`, `avdd` = PM8998 **L28** (2.856–3.312 V), `vdd` = GPIO23 fixed reg, reset GPIO32, INT GPIO31 level-low |
| Touch power | **L28 has `regulator-always-on`** — otherwise s2idle switches the controller off |
| Hall sensor | `gpio-hall` → `SW_LID` |
| Speaker amp | `ti,tas2557` + `ti,tas2559-reset-gpio` = GPIO76 |
| Sensors | accelerometer mount matrix (rotation), ambient light (auto-brightness) from the shared beryllium DTSI |
| USB | peripheral mode, RNDIS by default |
| Audio links | `SLIM Playback 1 / SLIM Capture 1` (SLIMBUS_0 + AIF1/AIF1_CAP), `VoiceMMode1` **cpu-only** (never add platform/codec — see NOTES) |

### Patches

| File | Purpose |
|---|---|
| `stmfts-touch.patch` | ST FTS5 support: sense-on command sequence (`0xa0 0x00 0x01`), CONTROL_READY polling, firmware flash helpers. This is what makes the stock `stmfts` driver work on this panel. |
| `rpmh-aggregate-enable.patch` | RPMh aggregate enable workaround (needed for the regulator votes on dipper) |
| `geni-i2c-no-dma.patch` | Adds an optional `qcom,no-dma` DT property. **Not applied by default** — kept for experiments; the touch bus still uses GPI DMA. |

### `config-postmarketos-qcom-sdm845-dipper.aarch64`

Notable deltas from the upstream sdm845 config: `CONFIG_QCOM_IPA`, `CONFIG_ATH10K_SNOC`,
`CONFIG_DRM_MSM`, `CONFIG_QCOM_Q6V5_MSS/PAS`, `CONFIG_SND_SOC_WCD934X`,
`CONFIG_SND_SOC_TAS2557`, and **module signature enforcement / lockdown disabled**
(so a new `boot.img` works with an older rootfs).

### `panel-samsung-ea8074.c`

EA8074 panel driver (DSI command mode, DCS brightness, no backlight class device).

## Device package

| File | Purpose |
|---|---|
| `deviceinfo` | flash offsets, **RNDIS + Linux-Foundation VID/PID** (Windows-friendly USB networking), initfs compression |
| `kernel-cmdline.conf` | `console=tty0`, `pmos.no-flash-kernel`, etc. |
| `modules-initfs` | modules needed in the initramfs (display, UFS, USB) |
| `a630_zap.mbn` | Adreno A630 zap shader (vendor blob) |
| `st_fts_e1.ftb` | ST touch controller firmware (vendor blob) |
| `usb-gadget-fixup.{service,sh,timer}` | re-creates the RNDIS gadget if it fails to come up |
| `00-device-xiaomi-dipper-gpu.files` / `post-install` | GPU firmware placement |

## Rootfs overlay (`overlay/`)

| Path | Purpose |
|---|---|
| `usr/share/alsa/ucm2/Xiaomi/dipper/HiFi.conf` | UCM: speaker (TAS2557), earpiece, both mics, headset jack |
| `usr/share/alsa/ucm2/conf.d/…` | UCM card hooks (`X8dipper`, `Xiaomi Mi 8 (dipper)`) so PulseAudio finds the verb |
| `lib/firmware/tas2557_uCDSP.bin` | TAS2557 DSP firmware (vendor blob) |
| `usr/local/bin/mi8-charge-limit.sh` + `etc/systemd/system/mi8-charge-limit.{service,timer}` | keeps the battery at 60–80 % by clamping `current_max` |
| `usr/local/bin/mi8-mic-route.sh` + `mi8-mic-route.service` | bottom-mic routing for the UCM capture device |
| `etc/pulse/default.pa.d/50-mi8-mic.pa` | PulseAudio source defaults |
| `usr/local/bin/mi8-power.sh` + `home/user/.config/systemd/user/mi8-power.service` | first-login auto-suspend policy (10 min) |
| `home/user/.config/systemd/user/mi8-{ambient,osk,im}.service` | auto-brightness gsettings, on-screen keyboard, IBus/libpinyin |
| `usr/lib/systemd/system-sleep/mi8-touch-resume` | **after resume**: re-bind `geni_i2c` + touch, restart the USB gadget |
| `usr/share/q6voiced/q6voiced.conf` | `card=0, device=4` — needed for q6voiced to even start (calls still blocked by the kernel) |
| `usr/local/bin/mi8-telnetd.service` etc. | debug access on `:2323` |
| `etc/gdm/custom.conf` | autologin (a locked-out session without touch is unrecoverable) |
| `usr/share/mi8-fixes/apks/*.apk` | offline ibus-libpinyin / libpinyin / kyotocabinet / pipewire-alsa, installed on first boot by `mi8-firstboot.service` |

## Known issues

### Voice calls: no audio (kernel limitation)

Chain of evidence:

```
q6voiced: Failed to open tx: Invalid argument
dmesg:    VoiceMMode1: ASoC: no backend DAIs enabled for VoiceMMode1
amixer:   'SLIMBUS_0_RX Voice Mixer VoiceMMode1' exists, but there is
          NO TX-direction voice mixer at all (0 of 120 VoiceMMode1 controls)
```

`q6routing` only creates RX voice mixers, so the `VoiceMMode1` **capture** has no
DPCM backend. `q6voiced` needs both directions, fails on tx, and the call stays
silent in both directions. Playback alone is not enough either — the DSP never
starts a voice session, so nothing arrives at `SLIMBUS_0_RX` even with a keep-alive
stream forcing the codec on.

Fix requires kernel work: implement TX voice routing in `q6routing`, or expose a
CS-VOICE PCM from the machine driver (see sdm845-mainline / pmaports!3639).

### Camera
Not configured. The IMX363 module builds, but no CSID/CCI/regulator setup is done.

### GPS
The GNSS stack is present but untested; expect partial functionality.

### Cosmetic
`clk-branch.c:88 WARNING` from `sd-bright` while toggling display clocks — harmless.
