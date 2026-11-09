# Hackintosh: MSI Z490-A PRO · Core i9-10900F · Radeon RX 580 · OpenCore

🇺🇦 Українська · [🇬🇧 English](README.en.md)

Робоча папка **EFI** для OpenCore на настільному комп'ютері з Comet Lake, відеокартою AMD Polaris,
Wi-Fi Broadcom BCM4360 і мережею 2,5 Гбіт/с. Модель Mac — **MacPro7,1**. Поруч на інших дисках стоїть **Windows 11**.

> [!IMPORTANT]
> Серійні номери в `EFI/OC/config.plist` замінено заглушками (`W00000000001`), а закриті драйвери Wi-Fi від Apple
> до репозиторію не входять. Перед використанням — розділ [Перед першим запуском](#перед-першим-запуском).

## Перевірено

| macOS | Збірка | Результат |
|---|---|---|
| Tahoe 26.5.2 | 25F84 | ✅ усе обладнання з таблиці нижче |

## Обладнання

| Компонент | Модель | Стан |
|---|---|---|
| Плата | MSI Z490-A PRO (MS-7C75), BIOS 7C75v2H1 | — |
| Процесор | Intel Core i9-10900F (Comet Lake, 10 ядер / 20 потоків, без вбудованої графіки) | ✅ XCPM |
| Пам'ять | 16 ГБ DDR4 | ✅ |
| Відеокарта | AMD Radeon RX 580, 8 ГБ (Polaris) | ✅ Metal, звук HDMI |
| NVMe | SK hynix BC501 256 ГБ (macOS) | ✅ NVMeFix, TRIM |
| SATA | 2 × HDD 1 ТБ | ✅ контролер AHCI через `compatible = pci8086,a182` |
| Мережа | Realtek RTL8125B, 2,5 Гбіт/с | ✅ RTL812xLucy 1.1.3 (перевірено на з'єднанні 1 Гбіт/с) |
| Wi-Fi | Broadcom BCM4360 (14E4:43A0) | ✅ патчі OCLP «Modern Wireless» (драйвер і прошивка вантажаться) |
| Bluetooth | Broadcom BCM20702 (USB) | ✅ клавіатура Bluetooth |
| Звук на платі | Realtek ALC897 (8086:06C8) | ✅ macOS 26 — VoodooHDA: 7.1 ззаду, навушники й мікрофон спереду |
| USB | Intel 400-series XHCI | ✅ карта на 15 портів (формат macOS 26) |
| Датчики | VirtualSMC | ✅ процесор і вентилятори |
| Сон | не налаштовувався | ⚠️ не перевірявся |

## Що всередині

- **OpenCore** з позначкою версії `REL-108 MOD` — збірка-форк OpenCorePkg з квірком `EnableForAll`
  (ACPI- і Booter-квірки застосовуються лише до macOS, Windows вантажиться без них).
- **SMBIOS:** `MacPro7,1`. **SecureBootModel:** `Disabled`, `revpatch=sbvmm,pci` (RestrictEvents).
- **ACPI:** `MaLd0n.aml` (набір Olarila: EC, `plugin-type`, USBX, PMCR, MCHC, SMBus) і патч FADT — значення скидання `0x06 → 0x0E`,
  щоб перезапуск з macOS був повним (інакше після перезапуску не працювала USB-клавіатура, а Windows зависала).
- **LauncherOption = Full** — OpenCore сам тримає свій запис першим у списку завантаження плати.

| Kext | Версія | Навіщо |
|---|---|---|
| Lilu | 1.7.3 | основа для інших розширень |
| VirtualSMC + SMCProcessor + SMCSuperIO | 1.3.8 | емуляція SMC, датчики |
| WhateverGreen | 1.7.1 | відеокарта (`agdpmod=pikera`) |
| AppleALC | 1.9.8 | вбудований звук до macOS 15 (`alcid=1`, `MaxKernel 24.99.99`) |
| RestrictEvents | 1.1.7 | оновлення ОС, без попереджень MacPro7,1 |
| NVMeFix | 1.1.4 | живлення NVMe |
| RTL812xLucy | 1.1.3 | мережа 2,5 Гбіт/с |
| USBMap | — | карта USB на 15 портів |
| AMFIPass ¹ | 1.4.1 | AMFI для патчів OCLP |
| IOSkywalkFamily ¹ | (OCLP) | пониження IOSkywalk для старого стеку Wi-Fi |
| IO80211FamilyLegacy + AirPortBrcmNIC ¹ | (OCLP) | Wi-Fi BCM4360 на macOS 14–15 |
| AirPortBrcmNIC-Tahoe ¹ | (OCLP) | Wi-Fi BCM4360 на macOS 26 |

¹ Закриті драйвери (Apple, Dhinak G.) до репозиторію не входять; записи в `config.plist` є, але вимкнені — див. нижче.

**Kernel → Block:** `com.apple.iokit.IOSkywalkFamily` (для пониження Skywalk) і `com.apple.driver.AppleEthernetRL` —
штатний драйвер RTL8125 від Apple прив'язаний до IOSkywalkFamily і з пониженим Skywalk падає; мережею керує RTL812xLucy.

**NVRAM:** `boot-args` = `alcid=1 watchdog=0 agdpmod=pikera ipc_control_port_options=0 -nokcmismatchpanic -amfipassbeta`,
`csr-active-config` = `03080000` (потрібно для патчів OCLP).

## Перед першим запуском

1. **Серійні номери.** [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) → `MacPro7,1`. Впишіть серійний номер, MLB і UUID
   у `PlatformInfo → Generic`, а також у `DataHub`, `PlatformNVRAM` і `SMBIOS` (там ті самі поля — заглушки `W00000000001`,
   `M0000000000000001`, `00000000-…`). `ROM` — MAC-адреса мережевої карти.
2. **Wi-Fi.** Завантажте з репозиторію [OpenCore Legacy Patcher, тег 3.0.0-rc.3](https://github.com/dortania/OpenCore-Legacy-Patcher/tree/3.0.0-rc.3/payloads/Kexts):
   `Wifi/IOSkywalkFamily-v1.2.0.zip`, `Wifi/IO80211FamilyLegacy-v1.0.0.zip`, `Wifi/AirPortBrcmNIC-Tahoe-v1.0.0.zip`,
   `Acidanthera/AMFIPass-v1.4.1-RELEASE.zip`. Розпакуйте `.kext` у `EFI/OC/Kexts/` і в `config.plist` увімкніть
   (`Enabled = true`) відповідні записи `Kernel → Add` та блок `IOSkywalkFamily` у `Kernel → Block`.
   Після встановлення macOS накладіть патчі в OpenCore Legacy Patcher («Post-Install Root Patch») і перезапустіть.
   Без Wi-Fi усе інше працює й так.
3. **BIOS** (Del → F7, розширений режим):
   - `Settings → Advanced → Windows OS Configuration`: Windows 10 WHQL Support — Disabled; Secure Boot — Disabled;
   - `Settings → Advanced → Integrated Peripherals`: SATA Mode — AHCI;
   - `Overclocking → CPU Features`: Intel VT-d — Disabled; CFG Lock — Disabled (якщо пункт є);
   - `Settings → Boot`: Boot mode — UEFI.
4. **Перевірка з флешки**, потім копіювання `EFI` на розділ EFI диска з macOS.

## macOS 26 Tahoe

- **Карта USB** містить нові ключі `usb-port-number` / `usb-port-type` (з ними macOS 26 бачить порти) і старі для macOS 15.
- **Вбудований звук.** У Tahoe немає AppleHDA, тому звук плати дає **VoodooHDA 3.6.8** з папки `PostInstall`:

```bash
sudo cp -R PostInstall/VoodooHDA.kext /Library/Extensions/
sudo chown -R root:wheel /Library/Extensions/VoodooHDA.kext
sudo chmod -R 755 /Library/Extensions/VoodooHDA.kext
sudo kmutil load -p /Library/Extensions/VoodooHDA.kext
```

Далі «Параметри → Конфіденційність і безпека» → «Дозволити» і перезапуск. У `Info.plist` змінено `IONameMatch` на `HDEF`
і прибрано особу для HDMI AMD — звук HDMI лишається за системним драйвером. Не використовуйте VoodooHDA_BL 3.7.0-alpha
(«для завантажувача»): вона вимикає системну IOAudioFamily, і зникає звук USB-карт і HDMI.

## Поруч Windows: скидання BIOS і Windows Boot Manager

Після скидання BIOS плата стирає свої записи завантаження. Якщо на розділі EFI диска з macOS лежить ще й завантажувач Windows,
плата називає цей диск «Windows Boot Manager» і вантажить з нього Windows, а до OpenCore не доходить.

Що зроблено на цьому комп'ютері:
1. **`LauncherOption = Full`** — OpenCore при кожному завантаженні сам відновлює і тримає свій запис першим
   (рятує від оновлень Windows; після скидання BIOS спрацює, щойно OpenCore буде запущено хоч раз).
2. **Запасна копія OpenCore там, де плата знаходить її сама:** розділ FAT32 з `EFI\BOOT\BOOTx64.efi` на диску Windows
   (плата показує його як «UEFI OS» і знаходить без жодних записів). Тут на цьому місці раніше лежала стара збірка — її замінено робочою.
3. **`tools/windows/Restore-OpenCore.cmd`** — з Windows створює запис «OpenCore» у платі й ставить його першим
   (`bcdedit /copy {bootmgr}` + шлях `\EFI\OC\OpenCore.efi`). Перед першим запуском впишіть у `restore_opencore.ps1` свій том EFI.

Перевірено: запис, створений через `bcdedit`, завантажив macOS після скидання BIOS. Справжнім повторним скиданням
пункти 1 і 2 ще не перевірялися.

## Встановлювальний пакет

`tools/macos-package/build.sh` збирає повний пакет `dist/Z490-A-PRO-Drivers-ДАТА.pkg` з вибором пунктів:
завантажувач OpenCore (ставиться, лише якщо його немає на розділі EFI системного диска), VoodooHDA (macOS 26+),
офіційний OpenCore Legacy Patcher (завантажується з GitHub, перевіряється підпис Dortania) і накладення патчів Wi-Fi
(`OpenCore-Patcher --patch_sys_vol`, лише якщо їх ще немає для поточної збірки macOS). Журнал — `/var/log/z490-drivers-install.log`.

## Історія змін

- **2026-11-09** — RTL812xLucy 1.1.1 → 1.1.3 (виправлено узгодження швидкості з повільнішим за 2,5 Гбіт/с партнером);
  `LauncherOption` Disabled → Full; AppleALC обмежено macOS 15; VoodooHDA для Tahoe; інструменти для Windows і пакет macOS.
- **2026-10-10** — карта USB у форматі macOS 26, драйвери Wi-Fi для Tahoe (за датами файлів).

## Подяки й ліцензії

- [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg) (acidanthera, BSD-3-Clause) і його форк із `EnableForAll`;
  Lilu, WhateverGreen, AppleALC, VirtualSMC, NVMeFix, RestrictEvents — acidanthera.
- [RTL812xLucy](https://github.com/Mieze/RTL812xLucy) — Laura Müller.
- [VoodooHDA](https://github.com/CloverHackyColor/VoodooHDA) — CloverHackyColor, GPL-2.0 (змінено лише `Info.plist`).
- [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) — Dortania; `MaLd0n.aml` — Olarila;
  `HfsPlus.efi` і ресурси меню — [OcBinaryData](https://github.com/acidanthera/OcBinaryData).

Власні файли репозиторію (опис, сценарії, `config.plist`, `USBMap.kext`) — [MIT](LICENSE).
Користуєтеся на власний ризик; macOS дозволено встановлювати лише на обладнання Apple.
