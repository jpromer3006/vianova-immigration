#!/bin/bash
# Creates ViaNova.app on your Desktop with the arc reactor icon.
# Run once:  bash launchers/make_mac_app.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Desktop/ViaNova.app"
chmod +x "$ROOT/launchers/ViaNova.command"

rm -rf "$APP"
osacompile -o "$APP" -e "do shell script quoted form of \"$ROOT/launchers/ViaNova.command\" & \" > /dev/null 2>&1 &\""

# Build an .icns from the PNG and apply it
ICONSET="$(mktemp -d)/vianova.iconset"; mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$ROOT/assets/vianova_icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d "$ROOT/assets/vianova_icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/applet.icns"
touch "$APP"
echo "ViaNova.app is on your Desktop. Drag it to the Dock if you like."
