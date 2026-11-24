# Build & flash

## 0. Host requirements

- Linux x86_64 (native or WSL2 Ubuntu works)
- `pmbootstrap` ≥ 3.0 — `pip install pmbootstrap`
- ~25 GB free space, `fastboot` (android-tools) for flashing
- A Xiaomi Mi 8 (dipper) with **unlocked bootloader**

## 1. Point pmbootstrap at a pmaports checkout

```bash
pmbootstrap init          # device: xiaomi, codename: dipper, UI: gnome, systemd: yes
pmbootstrap config aports   # prints the pmaports path, e.g. ~/.local/var/pmbootstrap/cache_git/pmaports
```

The first `init` clones pmaports (takes a while). Remember the printed path —
`build.sh` needs it (or just let it auto-detect).

## 2. Build

```bash
sudo ./scripts/build.sh
```

What it does, step by step (you can also run these by hand):

```bash
# 1. drop the packages in
cp -a pmaports/device/testing/*  "$APORTS/device/testing/"

# 2. initramfs patch: faster dynamic-partition scan (10 s -> 1 s)
cd "$APORTS" && patch -p1 < /path/to/patches/postmarketos-initramfs-fast-partscan.patch
pmbootstrap checksum postmarketos-initramfs

# 3. build
pmbootstrap build linux-postmarketos-qcom-sdm845-dipper
pmbootstrap build device-xiaomi-dipper

# 4. install into a chroot and export the boot image
pmbootstrap install --split
pmbootstrap export

# 5. inject the rootfs overlay (UCM, services, scripts, firmware)
./scripts/apply-overlay.sh rootfs.img
```

`build.sh` produces:

```
out/boot.img        -> flash to `boot`
out/rootfs.img      -> flash to `userdata`
```

## 3. Flash

> `userdata` will be **erased**. Back up anything you care about.

```bash
fastboot flash boot     out/boot.img
fastboot flash userdata out/rootfs.img
fastboot reboot
```

First boot takes 1–3 minutes (initramfs resizes the root filesystem).
Default user: `user` / `147147` (change it with `passwd` after first login).

## 4. Debug access

USB networking comes up as RNDIS with `172.16.42.1` (Linux Foundation VID/PID,
so Windows binds its native RNDIS driver instead of a stale ADB driver).

```bash
telnet 172.16.42.1 2323     # enabled by mi8-telnetd.service
```

If the phone is on Wi-Fi and you want network debugging without USB, allow the
port (nftables defaults to drop):

```bash
nft add rule inet filter input iifname "wlan*" tcp dport 2323 accept
```

## 5. Rebuild after changing the kernel package

```bash
pmbootstrap build linux-postmarketos-qcom-sdm845-dipper
pmbootstrap export boot        # only boot.img needs re-flashing
fastboot flash boot boot.img
```

`CONFIG_MODULE_SIG_FORCE`/lockdown is disabled in this package, so an old
rootfs keeps loading modules from a newer kernel — you do **not** have to
re-flash `userdata` for kernel-only changes.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `ASoC: failed to instantiate card -19` | a dai-link has a duplicate/missing codec; the `VoiceMMode1` link must stay cpu-only |
| Touch dead after long screen-off | GENI I2C lost its DMA engine — check `systemctl status` for the sleep hook, `journalctl -t mi8-touch` |
| `fastboot` sees no device | try another USB port/cable; bootloader USB is flaky on this device |
| Windows doesn't see the USB NIC | make sure `deviceinfo_usb_network_function="rndis.usb0"` is in effect |
