# Xiaomi Mi 8 (dipper) — postmarketOS mainline port

A working mainline Linux port of the **Xiaomi Mi 8 (dipper, SDM845)** for postmarketOS,
plus the kernel/device fixes that are not (yet) upstream.

This repo is meant to be *cloned and built*, not just read: the kernel package, the
device package and a rootfs overlay together reproduce the current state of the port.

```
Device:  Xiaomi Mi 8 (dipper)  ·  SoC: Qualcomm SDM845  ·  Display: Samsung EA8074 AMOLED
OS:      postmarketOS edge (systemd, GNOME)
Kernel:  7.1.0-rc1-sdm845 (linux-postmarketos-qcom-sdm845-dipper, pkgrel 109)
```

## What works

| Feature | Status | Notes |
|---|---|---|
| Display + brightness | ✅ | EA8074 panel driver, DCS brightness |
| Touchscreen | ✅ | ST FTS5 on I2C-14, custom STMFTS patch (sense-on, fw flash) |
| Touch after suspend | ✅ | resume hook rebuilds the GENI I2C controller |
| Auto-rotation | ✅ | accelerometer mount matrix + iio-sensor-proxy |
| Auto-brightness | ✅ | ambient light sensor + `mi8-ambient.service` |
| Speaker | ✅ | TAS2557 smart amp (needs vendor `tas2557_uCDSP.bin`) |
| Microphone | ✅ | bottom mic via DMIC/ADC path, `mi8-mic-route.service` |
| Wi-Fi | ✅ | WCN3990 / ath10k |
| LTE data + SMS | ✅ | IPA + ModemManager |
| GPU | ✅ | freedreno (a630) + `a630_zap.mbn` |
| USB networking | ✅ | RNDIS, `172.16.42.1` (Windows friendly) |
| Charge limit | ✅ | keeps 60–80 %, `mi8-charge-limit.timer` |
| Chinese input | ✅ | ibus-libpinyin (bundled offline apks) |
| Auto-suspend + power key | ✅ | suspend, resume hook restores touch/USB |
| **Voice calls** | ❌ | **No audio.** Kernel lacks TX voice routing (see below) |
| Camera | ❌ | not configured yet |
| GPS | ⚠️ | partially working, untested |

## Quick start

Requirements: a Linux x86_64 host with `pmbootstrap` installed (see
[docs/BUILD.md](docs/BUILD.md)), ~25 GB free disk.

```bash
git clone https://github.com/Lewis1996/xiaomi-dipper-postmarketos.git
cd xiaomi-dipper-postmarketos
sudo ./scripts/build.sh
```

`build.sh` will:

1. copy the two packages into your local `pmaports` checkout
2. apply the initramfs patch
3. build the kernel + device package
4. create the rootfs image and `boot.img`
5. inject the rootfs overlay (UCM, services, scripts, firmware)
6. print the two files to flash

Flash (bootloader unlocked):

```bash
fastboot flash boot   out/nura-boot.img
fastboot flash userdata out/nura-rootfs.img   # destructive, wipes data
fastboot reboot
```

## Repository layout

```
pmaports/device/testing/
  linux-postmarketos-qcom-sdm845-dipper/   kernel package: DTS, config, 3 patches
  device-xiaomi-dipper/                    device package: deviceinfo, firmware, USB gadget
patches/
  postmarketos-initramfs-fast-partscan.patch   faster dynamic-partition scan (10 s → 1 s)
overlay/                                   rootfs files not (yet) part of a package
  usr/share/alsa/ucm2/Xiaomi/dipper/       UCM (speaker, earpiece, mics)
  usr/local/bin/mi8-*.sh                   charge limit, mic routing, resume hook...
  etc/systemd/system/…                     services/timers
  home/user/.config/systemd/user/…          user services (ambient, IME, power policy)
scripts/
  build.sh                                 one-command build
  apply-overlay.sh                         inject overlay/ into a rootfs image
  make-image.sh                            rebuild kernel + image from a baseline
docs/
  BUILD.md   detailed build & flash instructions
  STATUS.md  feature matrix with what exactly was fixed and where
  NOTES.md   hard-won kernel/DTS knowledge (read this before hacking)
```

## The interesting parts

- **Touch is not a plain stmfts**: the controller needs a specific sense-on
  command sequence and its firmware is flashed at probe time — see
  `stmfts-touch.patch`.
- **Suspend kills the GENI I2C controller**, not the touch chip: after s2idle the
  GPI/DMA engine is dead (`GPI transfer failed: -5`), so the touch bus returns
  zeros. `usr/lib/systemd/system-sleep/mi8-touch-resume` re-binds `geni_i2c` and
  the touch controller after resume.
- **Charge limit is a software clamp** on `pmi8998-charger/current_max`; the
  driver resets it on USB re-negotiation, so the timer re-asserts it every 2 min.
- **Calls are blocked by the kernel**: `q6routing` only registers *RX* voice
  mixers, so `VoiceMMode1` capture has no DPCM backend (`no backend DAIs
  enabled`). `q6voiced` therefore fails with `Failed to open tx: Invalid
  argument`. See [docs/NOTES.md](docs/NOTES.md#voice-calls).

## Firmware / licensing

- Code is licensed **GPL-2.0-only** (see [LICENSE](LICENSE)).
- `a630_zap.mbn`, `st_fts_e1.ftb`, `tas2557_uCDSP.bin` are **vendor blobs**
  extracted from the device / stock firmware. They are *not* covered by the GPL
  and are included only to make the build self-contained for owners of the
  device. Remove them if you redistribute for other purposes.
- The offline apks under `overlay/usr/share/mi8-fixes/apks` are unmodified
  Alpine packages (ibus-libpinyin, libpinyin, kyotocabinet, pipewire-alsa).

## Credits

- postmarketOS / sdm845-mainline communities for the base port and kernel work
- The [Mechres/xiaomi-mi8-dipper](https://github.com/Mechres/xiaomi-mi8-dipper)
  bring-up notes, which this port started from
- Everyone who filed the sdm845 call-audio issues upstream
