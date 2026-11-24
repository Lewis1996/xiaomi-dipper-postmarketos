# Hard-won notes

Things that cost days. Read before changing anything.

## 1. Touch is not a stock `stmfts`

- Controller: ST FTS5 at `i2c14 0x49`, INT = GPIO31 (level low), RST = GPIO32,
  AVDD = PM8998 **L28**, VDDIO = GPIO23 fixed regulator.
- The controller **does not accept a plain GPIO reset pulse and then answers**.
  It needs the vendor "sense-on" sequence (`0xa0 0x00 0x01`, plus writes to
  `0x002c`) before it reports touches, otherwise you get a pointer that jumps and
  lags. `stmfts-touch.patch` implements that plus the firmware flash path.
- `reset_ms = 0` in the DTS means "do not pulse reset on power-on" — the firmware
  loaded at cold boot is preserved. Pulsing it without re-flashing leaves the
  controller uninitialised.

## 2. Suspend kills the I2C controller, not the touch chip

After s2idle resume the touch is dead, `chip_id` reads `0x0` and the interrupt
counter stops. The real error is:

```
geni_i2c a98000.i2c: DMA txn failed:3
geni_i2c a98000.i2c: GPI transfer failed: -5
```

The GENI SE's GPI/DMA engine is not restored by the driver's resume path, so *all*
I²C transfers fail. Two defences are in place:

1. **L28 `regulator-always-on`** — without it the controller loses power during
   s2idle and even a re-probe can't read the chip.
2. **`usr/lib/systemd/system-sleep/mi8-touch-resume`** — on `post|thaw` it re-binds
   `a98000.i2c` (which re-initialises GPI), then the touch driver, then restarts
   the USB gadget.

Historically (r27–r38) touch was moved to **i2c-gpio on GPIO33/34** to dodge this
entirely. That is the cleaner long-term fix; the DTS still carries the
`touch_i2c_gpio` pinctrl for it.

Watch out: `rtcwake -m freeze` bypasses systemd-sleep, so the hook does *not* run.
Test with `systemctl suspend` + a real power-key press.

## 3. Audio links — do not "improve" VoiceMMode1

```
dai-link-voicemmode1 { cpu { sound-dai = <&q6voicedai 1>; }; };
```

Adding a `platform` or `codec` subnode makes the whole card fail:

```
msm-snd-sdm845 sound: ASoC: failed to instantiate card -19
```

because `AIF1_PB` is already bound to `SLIM Playback 1` (and AIF2_PB to
`SLIM Playback 2`), so any codec reuse breaks registration. Leave it cpu-only.

`SLIMBUS_1_RX` cannot be started either: `AFE enable for port 0x4002 failed -22` —
this board only has the SLIMBUS_0 instance wired to the WCD9340.

## 4. Voice calls (current dead end)

sdm845 calls go through `q6voiced`, not through a normal PCM. It needs
`/usr/share/q6voiced/q6voiced.conf`, otherwise systemd silently skips the service:

```
ConditionPathExists=/usr/share/q6voiced/q6voiced.conf was not met
```

Correct content: `q6voice_card=0`, `q6voice_device=4` (VoiceMMode1 = `hw:0,4`).

But even then `Failed to open tx: Invalid argument` — and the reason is in the
kernel: `q6routing` registers only RX voice mixers (`SLIMBUS_0_RX Voice Mixer
VoiceMMode1` and friends), there is **no TX equivalent**, so capture has no DPCM
backend. This is the blocker; it needs a driver change, not a config change.

## 5. Charge limit is a moving target

Writing `0` to `pmi8998-charger/current_max` pauses charging, but the charger
driver **restores the default on every USB re-negotiation** (observed 1.4 A →
525 mA → back). A state-file based "I already paused" logic silently stops
working. The script therefore re-reads `current_max` on every timer tick and
re-asserts `0`. Note `status` still reads `Charging` — check `current_max`.

## 6. Suspend, wake sources and USB

- `pwrkey` and `rtc` are wake sources, but the RTC clock is at 1970, so
  `rtcwake` alarms do not fire reliably. Wake by power key.
- After s2idle the RNDIS gadget often does not come back; `mi8-touch-resume`
  restarts `usb-gadget-fixup.service` and the boot hook covers the rest.
- nftables input policy is `drop` and only `usb*` may reach 2323. To debug over
  Wi-Fi: `nft add rule inet filter input iifname "wlan*" tcp dport 2323 accept`.

## 7. Display brightness

AMOLED, no backlight class device. Brightness is DCS `0x51` via the panel driver;
`sd-bright` (or `brightnessctl`) writes it. The `clk-branch` WARNING during
brightness changes is expected noise.

## 8. Initramfs tweak

`postmarketos-initramfs` waits 10 s per attempt while scanning dynamic
partitions; on this device that is pure boot delay. The patch drops it to 1 s.
Remember to `pmbootstrap checksum postmarketos-initramfs` after patching or the
build aborts on a checksum mismatch.
