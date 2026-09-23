#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:-1.0.0}"
APP="$ROOT/dist/ReelConverter.app"
ICONSET="$ROOT/.build/ReelConverter.iconset"

swift build -c release
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp .build/release/ReelConverter "$APP/Contents/MacOS/ReelConverter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -s format png -z "$double" "$double" Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/ReelConverter.icns"
# Local builds have an ad-hoc signature; public releases require Developer ID signing and notarization.
codesign --force --sign - "$APP"
printf 'Built %s (%s)\n' "$APP" "$VERSION"
