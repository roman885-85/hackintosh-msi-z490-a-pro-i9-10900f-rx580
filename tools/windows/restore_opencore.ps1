# Повертає в плату (UEFI) запис завантаження OpenCore і ставить його першим.
# Потрібно після скидання BIOS або коли оновлення Windows ставить Windows Boot Manager першим.
# Запуск: подвійним клацанням по Restore-OpenCore.cmd (сам попросить права адміністратора).
#
# ПЕРЕД ПЕРШИМ ЗАПУСКОМ впишіть у $EspVolume том розділу EFI, на якому лежить EFI\OC\OpenCore.efi.
# Як дізнатися: у PowerShell адміністратора виконайте
#   Get-Partition | ? GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' | ft DiskNumber,PartitionNumber,Size,AccessPaths
# і візьміть рядок \\?\Volume{...}\ потрібного диска (того, де стоїть macOS).
param(
  [string]$EspVolume = '\\?\Volume{00000000-0000-0000-0000-000000000000}\',
  [string]$EntryName = 'OpenCore'
)
$ErrorActionPreference = 'Stop'
if ($EspVolume -like '*00000000-0000-0000-0000-000000000000*') { throw "Спершу впишіть у сценарій свій том EFI (змінна EspVolume) - див. коментар на початку файлу" }
$fw = (bcdedit /enum firmware) -join "`n"
$mine = @($fw -split "`n`n" | ? { $_ -match ('(?m)^description\s+' + [regex]::Escape($EntryName) + '\s*$') })
if ($mine.Count -gt 0) {
  $id = [regex]::Match($mine[0], '\{[0-9a-fA-F-]{36}\}').Value
  "Запис уже є: $id - ставлю першим"
} else {
  mountvol S: $EspVolume
  try {
    if (-not (Test-Path 'S:\EFI\OC\OpenCore.efi')) { throw "На вказаному розділі немає EFI\OC\OpenCore.efi" }
    $out = bcdedit /copy '{bootmgr}' /d $EntryName
    $id = [regex]::Match(($out -join ' '), '\{[0-9a-fA-F-]{36}\}').Value
    if (-not $id) { throw "bcdedit не створив запис: $out" }
    bcdedit /set $id device partition=S: | Out-Null
    bcdedit /set $id path '\EFI\OC\OpenCore.efi' | Out-Null
    "Створено запис $id"
  } finally { mountvol S: /D }
}
bcdedit /set '{fwbootmgr}' displayorder $id /addfirst | Out-Null
"Готово. Перезапустіть комп'ютер - має відкритися OpenCore."
