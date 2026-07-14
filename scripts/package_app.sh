#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Task.app"
BUILD="$ROOT/.build/release"

cd "$ROOT"
swift build -c release --product TaskApp
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/TaskApp" "$APP/Contents/MacOS/TaskApp"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"

for bundle in "$BUILD"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
done

codesign --force --deep --sign - "$APP"
echo "$APP"
