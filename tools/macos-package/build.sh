#!/bin/bash
# Збирає встановлювальний пакет macOS для MSI Z490-A PRO.
#   ./tools/macos-package/build.sh              — драйвери: вбудований звук (VoodooHDA, macOS 26+) і патчі Wi-Fi OCLP;
#   ... --with-efi                              — ще й завантажувач OpenCore з EFI/ (спершу впишіть свої серійні номери);
#   ... --with-oclp                             — ще й офіційний OpenCore Legacy Patcher 3.0.0-rc.3 (завантажується з GitHub,
#                                                  перевіряється підпис Dortania; OCLP_PKG=/шлях/OpenCore-Patcher.pkg — узяти готовий).
# Ключі можна поєднувати. Результат — dist/Z490-A-PRO-Drivers[-with-EFI][-with-OCLP]-ВЕРСІЯ.pkg
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
V=${VERSION:-$(date +%Y.%m.%d)}
OCLP_URL="https://github.com/dortania/OpenCore-Legacy-Patcher/releases/download/3.0.0-rc.3/OpenCore-Patcher.pkg"
WITH_EFI=0; WITH_OCLP=0
for a in "$@"; do case "$a" in --with-efi) WITH_EFI=1 ;; --with-oclp) WITH_OCLP=1 ;; *) echo "невідомий ключ: $a"; exit 1 ;; esac; done
if [ $WITH_EFI = 1 ] && grep -q "W00000000001" "$REPO/EFI/OC/config.plist"; then
  echo "У EFI/OC/config.plist заглушки серійних номерів (W00000000001). Згенеруйте свої (GenSMBIOS, MacPro7,1),"
  echo "впишіть у PlatformInfo (Generic, DataHub, PlatformNVRAM, SMBIOS) і запустіть збирання ще раз."; exit 1
fi
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/comp" "$WORK/res" "$REPO/dist"
SUPDIR="Library/Application Support/Z490-A-PRO-Drivers"
LINES=""; CHOICES=""; REFS=""

component() { # id root(або порожньо) script out
  local id=$1 root=$2 script=$3 out=$4 n i
  mkdir -p "$WORK/s-$id"; cp "$HERE/scripts/$script" "$WORK/s-$id/postinstall"; chmod 755 "$WORK/s-$id/postinstall"
  if [ -n "$root" ]; then
    find "$root" \( -name "._*" -o -name ".DS_Store" \) -delete
    pkgbuild --analyze --root "$root" "$WORK/$id.plist" >/dev/null
    n=$(/usr/libexec/PlistBuddy -c "Print" "$WORK/$id.plist" | grep -c "RootRelativeBundlePath" || true)
    for ((i=0; i<n; i++)); do
      /usr/libexec/PlistBuddy -c "Set :$i:BundleIsRelocatable false" "$WORK/$id.plist" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Add :$i:BundleIsRelocatable bool false" "$WORK/$id.plist"
    done
    pkgbuild --root "$root" --component-plist "$WORK/$id.plist" --scripts "$WORK/s-$id" --identifier "$id" \
      --version "$V" --install-location / --ownership recommended "$WORK/comp/$out" >/dev/null
  else
    pkgbuild --nopayload --scripts "$WORK/s-$id" --identifier "$id" --version "$V" "$WORK/comp/$out" >/dev/null
  fi
  echo "компонент $out готовий"
}
add_choice() { # choice-id pkg-id file title description onConclusion version
  LINES="$LINES<line choice=\"$1\"/>"
  CHOICES="$CHOICES<choice id=\"$1\" title=\"$4\" description=\"$5\"><pkg-ref id=\"$2\"/></choice>"
  REFS="$REFS<pkg-ref id=\"$2\" version=\"$7\" onConclusion=\"$6\">$3</pkg-ref>"
}

SUFFIX=""
if [ $WITH_EFI = 1 ]; then
  mkdir -p "$WORK/r-oc/$SUPDIR"; cp -R "$REPO/EFI" "$WORK/r-oc/$SUPDIR/EFI"
  component ua.local.z490.opencore "$WORK/r-oc" opencore-postinstall z490-opencore.pkg
  add_choice oc ua.local.z490.opencore z490-opencore.pkg "Завантажувач OpenCore" "OpenCore на розділ EFI системного диска, якщо його там немає." none "$V"
  SUFFIX="$SUFFIX-with-EFI"
fi
mkdir -p "$WORK/r-vhda/$SUPDIR"; cp -R "$REPO/PostInstall/VoodooHDA.kext" "$WORK/r-vhda/$SUPDIR/"
component ua.local.z490.voodoohda "$WORK/r-vhda" voodoohda-postinstall z490-voodoohda.pkg
add_choice vhda ua.local.z490.voodoohda z490-voodoohda.pkg "Вбудований звук (VoodooHDA)" "Realtek ALC897 на macOS 26 і новіших. Потрібен дозвіл у «Конфіденційність і безпека» і перезапуск." none "$V"
if [ $WITH_OCLP = 1 ]; then
  OCLP_SRC=${OCLP_PKG:-}
  if [ -z "$OCLP_SRC" ]; then
    echo "завантажую OpenCore Legacy Patcher 3.0.0-rc.3 (~890 МБ)..."
    curl -fL --progress-bar -o "$WORK/oclp.pkg" "$OCLP_URL"; OCLP_SRC="$WORK/oclp.pkg"
  fi
  pkgutil --check-signature "$OCLP_SRC" | grep -q "Developer ID Installer: Mykola Grymalyuk" || { echo "пакет OCLP не підписаний Dortania — зупиняюсь"; exit 1; }
  pkgutil --expand "$OCLP_SRC" "$WORK/oclp-x"
  pkgutil --flatten "$WORK/oclp-x/OpenCore-Patcher.pkg" "$WORK/comp/OpenCore-Patcher.pkg"
  OCLP_VER=$(sed -n 's/.*pkg-ref id="com.dortania.opencore-legacy-patcher" version="\([^"]*\)".*/\1/p' "$WORK/oclp-x/Distribution" | head -1)
  add_choice oclp com.dortania.opencore-legacy-patcher OpenCore-Patcher.pkg "OpenCore Legacy Patcher $OCLP_VER" "Офіційний пакет Dortania без змін; потрібен для Wi-Fi Broadcom." none "$OCLP_VER"
  echo "компонент OCLP $OCLP_VER готовий"
  SUFFIX="$SUFFIX-with-OCLP"
fi
component ua.local.z490.wifi-rootpatch "" wifi-postinstall z490-wifi-rootpatch.pkg
add_choice wifi ua.local.z490.wifi-rootpatch z490-wifi-rootpatch.pkg "Wi-Fi Broadcom: патчі OCLP" "На macOS 14+ накладає патчі «Modern Wireless», якщо їх немає для цієї збірки macOS. Потрібен встановлений OCLP." RequireRestart "$V"

cp "$HERE/resources/"*.html "$WORK/res/"
cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Драйвери MSI Z490-A PRO</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <options customize="allow" require-scripts="false" hostArchitectures="x86_64" rootVolumeOnly="true"/>
  <domains enable_localSystem="true"/>
  <choices-outline>$LINES</choices-outline>
  $CHOICES
  $REFS
</installer-gui-script>
XML
OUT="$REPO/dist/Z490-A-PRO-Drivers$SUFFIX-$V.pkg"
productbuild --distribution "$WORK/distribution.xml" --resources "$WORK/res" --package-path "$WORK/comp" "$OUT" >/dev/null
echo "Готово: $OUT"
