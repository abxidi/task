#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Task.app"
BUILD="$ROOT/.build/release"
ICON_SOURCE="$ROOT/Sources/TaskApp/Resources/Assets.xcassets/AppIcon.appiconset"
ICONSET="$BUILD/Task.iconset"

cd "$ROOT"
swift build -c release --product TaskApp
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/TaskApp" "$APP/Contents/MacOS/TaskApp"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$ICON_SOURCE/icon_16.png" "$ICONSET/icon_16x16.png"
cp "$ICON_SOURCE/icon_16@2x.png" "$ICONSET/icon_16x16@2x.png"
cp "$ICON_SOURCE/icon_32.png" "$ICONSET/icon_32x32.png"
cp "$ICON_SOURCE/icon_32@2x.png" "$ICONSET/icon_32x32@2x.png"
cp "$ICON_SOURCE/icon_128.png" "$ICONSET/icon_128x128.png"
cp "$ICON_SOURCE/icon_128@2x.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICON_SOURCE/icon_256.png" "$ICONSET/icon_256x256.png"
cp "$ICON_SOURCE/icon_256@2x.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICON_SOURCE/icon_512.png" "$ICONSET/icon_512x512.png"
cp "$ICON_SOURCE/icon_512@2x.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Task.icns"

for bundle in "$BUILD"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

codesign --force --deep --sign - "$APP"
echo "$APP"
