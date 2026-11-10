# Hackintosh: MSI Z490-A PRO · Core i9-10900F · Radeon RX 580 · OpenCore

[🇺🇦 Українська](README.md) · 🇬🇧 English

A working OpenCore **EFI** folder for a Comet Lake desktop with an AMD Polaris GPU,
Broadcom BCM4360 Wi-Fi and 2.5 Gbit/s Ethernet. SMBIOS is **MacPro7,1**. **Windows 11** lives on other disks.

> [!IMPORTANT]
> The serial numbers in `EFI/OC/config.plist` are placeholders (`W00000000001`), and Apple's closed-source Wi-Fi kexts
> are not included. Before use, read [Before the first boot](#before-the-first-boot).

## Tested

| macOS | Build | Result |
|---|---|---|
| Tahoe 26.5.2 | 25F84 | ✅ all hardware listed below |

## Hardware

| Component | Model | Status |
|---|---|---|
| Motherboard | MSI Z490-A PRO (MS-7C75), BIOS 7C75v2H1 | — |
| CPU | Intel Core i9-10900F (Comet Lake, 10 cores / 20 threads, no iGPU) | ✅ XCPM |
| RAM | 16 GB DDR4 | ✅ |
| GPU | AMD Radeon RX 580, 8 GB (Polaris) | ✅ Metal, HDMI audio |
| NVMe | SK hynix BC501 256 GB (macOS) | ✅ NVMeFix, TRIM |
| SATA | 2 × 1 TB HDD | ✅ AHCI controller via `compatible = pci8086,a182` |
| Ethernet | Realtek RTL8125B, 2.5 Gbit/s | ✅ RTL812xLucy 1.1.3 (tested on a 1 Gbit/s link) |
| Wi-Fi | Broadcom BCM4360 (14E4:43A0) | ✅ OCLP "Modern Wireless" root patch (driver and firmware load) |
| Bluetooth | Broadcom BCM20702 (USB) | ✅ Bluetooth keyboard |
| Onboard audio | Realtek ALC897 (8086:06C8) | ✅ macOS 26 — VoodooHDA: rear 7.1, front headphones and mic |
| USB | Intel 400-series XHCI | ✅ 15-port map (macOS 26 format) |
| Sensors | VirtualSMC | ✅ CPU and fans |
| Sleep | not configured | ⚠️ not tested |

## What's inside

- **OpenCore** reporting `REL-108 MOD` — an OpenCorePkg fork with the `EnableForAll` quirk
  (ACPI and Booter quirks apply to macOS only; Windows boots without them). The official `ocvalidate` 1.0.8 flags only
  this fork's three keys (`EnableForAll` ×2, `SkipCustomEntryCheck`) as unknown — nothing else.
- **SMBIOS:** `MacPro7,1`. **SecureBootModel:** `Disabled`, `revpatch=sbvmm,pci` (RestrictEvents).
- **ACPI:** `MaLd0n.aml` (Olarila bundle: EC, `plugin-type`, USBX, PMCR, MCHC, SMBus) and an FADT patch — reset value `0x06 → 0x0E`,
  so a restart from macOS is a full reset (otherwise the USB keyboard was dead after a restart and Windows hung).
- **LauncherOption = Full** — OpenCore keeps its own boot entry first in the firmware boot list.

| Kext | Version | Purpose |
|---|---|---|
| Lilu | 1.7.3 | patching framework |
| VirtualSMC + SMCProcessor + SMCSuperIO | 1.3.8 | SMC emulation, sensors |
| WhateverGreen | 1.7.1 | GPU (`agdpmod=pikera`) |
| AppleALC | 1.9.8 | onboard audio up to macOS 15 (`alcid=1`, `MaxKernel 24.99.99`) |
| RestrictEvents | 1.1.7 | OS updates, no MacPro7,1 warnings |
| NVMeFix | 1.1.4 | NVMe power management |
| RTL812xLucy | 1.1.3 | 2.5 Gbit/s Ethernet |
| USBMap | — | 15-port USB map |
| AMFIPass ¹ | 1.4.1 | AMFI for OCLP root patches |
| IOSkywalkFamily ¹ | (OCLP) | IOSkywalk downgrade for the legacy Wi-Fi stack |
| IO80211FamilyLegacy + AirPortBrcmNIC ¹ | (OCLP) | BCM4360 Wi-Fi on macOS 14–15 |
| AirPortBrcmNIC-Tahoe ¹ | (OCLP) | BCM4360 Wi-Fi on macOS 26 |

¹ Closed-source kexts (Apple, Dhinak G.) are not included; their `config.plist` entries exist but are disabled — see below.

**Kernel → Block:** `com.apple.iokit.IOSkywalkFamily` (for the Skywalk downgrade) and `com.apple.driver.AppleEthernetRL` —
Apple's own RTL8125 driver links to IOSkywalkFamily and panics with a downgraded Skywalk; RTL812xLucy drives the NIC instead.

**NVRAM:** `boot-args` = `alcid=1 watchdog=0 agdpmod=pikera ipc_control_port_options=0 -nokcmismatchpanic -amfipassbeta`,
`csr-active-config` = `03080000` (required for OCLP root patches).

## Before the first boot

1. **Serial numbers.** [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) → `MacPro7,1`. Put the serial, MLB and UUID into
   `PlatformInfo → Generic`, and also into `DataHub`, `PlatformNVRAM` and `SMBIOS` (same fields, placeholders `W00000000001`,
   `M0000000000000001`, `00000000-…`). `ROM` — your Ethernet MAC address.
2. **Wi-Fi.** Download from the [OpenCore Legacy Patcher repository, tag 3.0.0-rc.3](https://github.com/dortania/OpenCore-Legacy-Patcher/tree/3.0.0-rc.3/payloads/Kexts):
   `Wifi/IOSkywalkFamily-v1.2.0.zip`, `Wifi/IO80211FamilyLegacy-v1.0.0.zip`, `Wifi/AirPortBrcmNIC-Tahoe-v1.0.0.zip`,
   `Acidanthera/AMFIPass-v1.4.1-RELEASE.zip`. Unzip the `.kext` bundles into `EFI/OC/Kexts/` and in `config.plist` enable
   (`Enabled = true`) the matching `Kernel → Add` entries and the `IOSkywalkFamily` entry in `Kernel → Block`.
   After installing macOS, apply the root patch in OpenCore Legacy Patcher ("Post-Install Root Patch") and restart.
   Everything else works without Wi-Fi anyway.
3. **BIOS** (Del → F7, advanced mode):
   - `Settings → Advanced → Windows OS Configuration`: Windows 10 WHQL Support — Disabled; Secure Boot — Disabled;
   - `Settings → Advanced → Integrated Peripherals`: SATA Mode — AHCI;
   - `Overclocking → CPU Features`: Intel VT-d — Disabled; CFG Lock — Disabled (if present);
   - `Settings → Boot`: Boot mode — UEFI.
4. **Test from a USB stick** first, then copy `EFI` to the EFI partition of the macOS disk.

## macOS 26 Tahoe

- **The USB map** carries the new `usb-port-number` / `usb-port-type` keys (macOS 26 needs them to see the ports) and the old ones for macOS 15.
- **Onboard audio.** Tahoe has no AppleHDA, so board audio comes from **VoodooHDA 3.6.8** in `PostInstall`:

```bash
sudo cp -R PostInstall/VoodooHDA.kext /Library/Extensions/
sudo chown -R root:wheel /Library/Extensions/VoodooHDA.kext
sudo chmod -R 755 /Library/Extensions/VoodooHDA.kext
sudo kmutil load -p /Library/Extensions/VoodooHDA.kext
```

Then System Settings → Privacy & Security → "Allow", and restart. In `Info.plist`, `IONameMatch` is changed to `HDEF`
and the AMD HDMI personality removed — HDMI audio stays with the system driver. Do not use VoodooHDA_BL 3.7.0-alpha
(the "bootloader" build): it knocks out the system IOAudioFamily, and USB and HDMI audio disappear.

## Windows next door: BIOS resets and Windows Boot Manager

A BIOS reset wipes the firmware boot entries. If the EFI partition of the macOS disk also holds the Windows boot loader,
the board calls that disk "Windows Boot Manager", boots Windows from it and never reaches OpenCore.

What is set up on this machine:
1. **`LauncherOption = Full`** — on every boot OpenCore restores and keeps its entry first
   (protects against Windows updates; after a BIOS reset it kicks in as soon as OpenCore is started once).
2. **A fallback copy of OpenCore where the board finds it on its own:** a FAT32 partition with `EFI\BOOT\BOOTx64.efi` on the Windows disk
   (the board lists it as "UEFI OS" without any entries). An old build used to sit there — it has been replaced with the working one.
3. **`tools/windows/Restore-OpenCore.cmd`** — from Windows, creates an "OpenCore" firmware entry and puts it first
   (`bcdedit /copy {bootmgr}` + path `\EFI\OC\OpenCore.efi`). Set your EFI volume in `restore_opencore.ps1` before the first run.

Verified: the entry created with `bcdedit` booted macOS after the BIOS reset. Items 1 and 2 have not yet been tested by a real second reset.

## Driver package

A ready package is in [Releases](https://github.com/roman885-85/hackintosh-msi-z490-a-pro-i9-10900f-rx580/releases/latest):
`Z490-A-PRO-Drivers-DATE.pkg`. Install it **after** macOS is installed; use "Customize" to untick any item.

| Item | What it does |
|---|---|
| Onboard audio (VoodooHDA) | on macOS 26+ installs VoodooHDA 3.6.8 into `/Library/Extensions` (Realtek ALC897) and triggers the approval prompt |
| Broadcom Wi-Fi: OCLP root patch | on macOS 14+ runs `OpenCore-Patcher --patch_sys_vol` if the "Modern Wireless" patches are not yet applied for the current macOS build; does nothing without OCLP installed |

**How to install:**
1. For Wi-Fi first: add the Wi-Fi kexts to the EFI and enable them ([Before the first boot](#before-the-first-boot), step 2), restart,
   then install [OpenCore Legacy Patcher 3.0.0-rc.3](https://github.com/dortania/OpenCore-Legacy-Patcher/releases/tag/3.0.0-rc.3)
   (Dortania's `OpenCore-Patcher.pkg`). Skip this step if you don't need Wi-Fi.
2. Download the driver package from Releases.
3. The package is not signed with an Apple certificate, so macOS won't open it with a double-click. Use any of these:
   - remove the download flag and open it as usual:
     ```bash
     xattr -d com.apple.quarantine ~/Downloads/Z490-A-PRO-Drivers-*.pkg
     ```
   - or System Settings → Privacy & Security → "Open Anyway" after the first attempt;
   - or install from Terminal without the GUI:
     ```bash
     sudo installer -pkg ~/Downloads/Z490-A-PRO-Drivers-*.pkg -target /
     ```
4. Go through the installer steps (the Wi-Fi root patch takes 2–5 minutes).
5. System Settings → Privacy & Security → "Allow" next to VoodooHDA.
6. Restart — "Realtek ALC897" devices and Wi-Fi appear.

Log: `/var/log/z490-drivers-install.log`.

**Your own full package.** `./tools/macos-package/build.sh --with-efi --with-oclp` builds a package that also installs OpenCore to the
EFI partition of the system disk (only if it is not there; put your serials in first) and the official OCLP (downloaded from GitHub,
Dortania signature checked). The flags can be used separately.

## Changelog

- **2026-11-10** — a ready driver package in Releases (VoodooHDA, OCLP Wi-Fi root patch) with step-by-step instructions; build flags `--with-efi` and `--with-oclp`.
- **2026-11-09** — RTL812xLucy 1.1.1 → 1.1.3 (fixed link negotiation with partners slower than 2.5 Gbit/s);
  `LauncherOption` Disabled → Full; AppleALC limited to macOS 15; VoodooHDA for Tahoe; Windows tools and macOS package.
- **2026-10-10** — USB map in macOS 26 format, Wi-Fi kexts for Tahoe (per file dates).

## Credits & licenses

- [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg) (acidanthera, BSD-3-Clause) and its fork with `EnableForAll`;
  Lilu, WhateverGreen, AppleALC, VirtualSMC, NVMeFix, RestrictEvents — acidanthera.
- [RTL812xLucy](https://github.com/Mieze/RTL812xLucy) — Laura Müller.
- [VoodooHDA](https://github.com/CloverHackyColor/VoodooHDA) — CloverHackyColor, GPL-2.0 (only `Info.plist` modified).
- [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) — Dortania; `MaLd0n.aml` — Olarila;
  `HfsPlus.efi` and picker resources — [OcBinaryData](https://github.com/acidanthera/OcBinaryData).

This repository's own files (docs, scripts, `config.plist`, `USBMap.kext`) — [MIT](LICENSE).
Use at your own risk; Apple's license allows macOS on Apple hardware only.
