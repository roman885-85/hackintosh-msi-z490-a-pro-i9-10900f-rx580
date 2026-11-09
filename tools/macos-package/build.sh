#!/bin/bash
# Збирає повний встановлювальний пакет macOS dist/Z490-A-PRO-Drivers-ВЕРСІЯ.pkg з чотирма пунктами:
#   завантажувач OpenCore (EFI/), вбудований звук (PostInstall/VoodooHDA.kext),
#   OpenCore Legacy Patcher (офіційний пакет Dortania без змін), патчі Wi-Fi OCLP.
# Запуск: ./tools/macos-package/build.sh
#   OCLP_PKG=/шлях/OpenCore-Patcher.pkg — узяти вже завантажений пакет OCLP замість завантаження.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
V=${VERSION:-$(date +%Y.%m.%d)}
OCLP_URL="https://github.com/dortania/OpenCore-Legacy-Patcher/releases/download/3.0.0-rc.3/OpenCore-Patcher.pkg"
if grep -q "W00000000001" "$REPO/EFI/OC/config.plist"; then
  echo "УВАГА: у EFI/OC/config.plist заглушки серійних номерів (W00000000001)."
  echo "Згенеруйте свої (GenSMBIOS, модель MacPro7,1) і впишіть у PlatformInfo (Generic, DataHub, PlatformNVRAM, SMBIOS)."
fi
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/comp" "$WORK/res" "$REPO/dist"
SUPDIR="Library/Application Support/Z490-A-PRO-Drivers"

component() { # id root scripts-file out
  local id=$1 root=$2 script=$3 out=$4
  mkdir -p "$WORK/s-$id"; cp "$HERE/scripts/$script" "$WORK/s-$id/postinstall"; chmod 755 "$WORK/s-$id/postinstall"
  if [ -n "$root" ]; then
    find "$root" \( -name "._*" -o -name ".DS_Store" \) -delete
    pkgbuild --analyze --root "$root" "$WORK/$id.plist" >/dev/null
    local n i; n=$(/usr/libexec/PlistBuddy -c "Print" "$WORK/$id.plist" | grep -c "RootRelativeBundlePath" || true)
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

mkdir -p "$WORK/r-oc/$SUPDIR" "$WORK/r-vhda/$SUPDIR"
cp -R "$REPO/EFI" "$WORK/r-oc/$SUPDIR/EFI"
cp -R "$REPO/PostInstall/VoodooHDA.kext" "$WORK/r-vhda/$SUPDIR/"
component ua.local.z490.opencore       "$WORK/r-oc"   opencore-postinstall  z490-opencore.pkg
component ua.local.z490.voodoohda      "$WORK/r-vhda" voodoohda-postinstall z490-voodoohda.pkg
component ua.local.z490.wifi-rootpatch ""             wifi-postinstall      z490-wifi-rootpatch.pkg

OCLP_SRC=${OCLP_PKG:-}
if [ -z "$OCLP_SRC" ]; then
  echo "завантажую OpenCore Legacy Patcher 3.0.0-rc.3 (~890 МБ)..."
  curl -fL --progress-bar -o "$WORK/oclp.pkg" "$OCLP_URL"; OCLP_SRC="$WORK/oclp.pkg"
fi
pkgutil --check-signature "$OCLP_SRC" | grep -q "Developer ID Installer: Mykola Grymalyuk" || { echo "пакет OCLP не підписаний Dortania — зупиняюсь"; exit 1; }
pkgutil --expand "$OCLP_SRC" "$WORK/oclp-x"
pkgutil --flatten "$WORK/oclp-x/OpenCore-Patcher.pkg" "$WORK/comp/OpenCore-Patcher.pkg"
OCLP_VER=$(sed -n 's/.*pkg-ref id="com.dortania.opencore-legacy-patcher" version="\([^"]*\)".*/\1/p' "$WORK/oclp-x/Distribution" | head -1)
echo "компонент OCLP $OCLP_VER готовий"

cp "$HERE/resources/"*.html "$WORK/res/"
cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Драйвери MSI Z490-A PRO</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <conclusion file="conclusion.html" mime-type="text/html"/>
  <options customize="allow" require-scripts="false" hostArchitectures="x86_64" rootVolumeOnly="true"/>
  <domains enable_localSystem="true"/>
  <choices-outline>
    <line choice="oc"/><line choice="vhda"/><line choice="oclp"/><line choice="wifi"/>
  </choices-outline>
  <choice id="oc" title="Завантажувач OpenCore" description="OpenCore на розділ EFI системного диска, якщо його там немає."><pkg-ref id="ua.local.z490.opencore"/></choice>
  <choice id="vhda" title="Вбудований звук (VoodooHDA)" description="Realtek ALC897 на macOS 26 і новіших. Потрібен дозвіл у «Конфіденційність і безпека» і перезапуск."><pkg-ref id="ua.local.z490.voodoohda"/></choice>
  <choice id="oclp" title="OpenCore Legacy Patcher $OCLP_VER" description="Офіційний пакет Dortania без змін; потрібен для Wi-Fi Broadcom."><pkg-ref id="com.dortania.opencore-legacy-patcher"/></choice>
  <choice id="wifi" title="Wi-Fi Broadcom: патчі OCLP" description="На macOS 14+ накладає патчі «Modern Wireless», якщо їх немає для цієї збірки macOS."><pkg-ref id="ua.local.z490.wifi-rootpatch"/></choice>
  <pkg-ref id="ua.local.z490.opencore" version="$V" onConclusion="none">z490-opencore.pkg</pkg-ref>
  <pkg-ref id="ua.local.z490.voodoohda" version="$V" onConclusion="none">z490-voodoohda.pkg</pkg-ref>
  <pkg-ref id="com.dortania.opencore-legacy-patcher" version="$OCLP_VER" onConclusion="none">OpenCore-Patcher.pkg</pkg-ref>
  <pkg-ref id="ua.local.z490.wifi-rootpatch" version="$V" onConclusion="RequireRestart">z490-wifi-rootpatch.pkg</pkg-ref>
</installer-gui-script>
XML
productbuild --distribution "$WORK/distribution.xml" --resources "$WORK/res" --package-path "$WORK/comp" \
  "$REPO/dist/Z490-A-PRO-Drivers-$V.pkg"
echo "Готово: $REPO/dist/Z490-A-PRO-Drivers-$V.pkg"
