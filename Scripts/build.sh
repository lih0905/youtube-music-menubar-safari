#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
DIST_DIR="$ROOT_DIR/Dist"
APP_NAME="YouTubeMusicMenuBar"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
RES_DIR="$CONTENTS_DIR/Resources"
MACOS_DIR="$CONTENTS_DIR/MacOS"

mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$RES_DIR" "$MACOS_DIR"

clang -fobjc-arc -framework Cocoa "$ROOT_DIR/Scripts/generate_icon.m" -o "$BUILD_DIR/generate_icon"
"$BUILD_DIR/generate_icon" "$BUILD_DIR"

cp "$BUILD_DIR/ytmusic_status.png" "$RES_DIR/ytmusic_status.png"
cp "$BUILD_DIR/ytmusic_1024.png" "$RES_DIR/AppIcon.png"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

clang -fobjc-arc -framework Cocoa -framework QuartzCore \
  "$ROOT_DIR/Sources/main.m" \
  "$ROOT_DIR/Sources/AppDelegate.m" \
  "$ROOT_DIR/Sources/PlayerState.m" \
  "$ROOT_DIR/Sources/SafariBridge.m" \
  "$ROOT_DIR/Sources/PopoverViewController.m" \
  -o "$MACOS_DIR/$APP_NAME"



rm -f "$DIST_DIR/$APP_NAME.zip"
cd "$BUILD_DIR"
/usr/bin/zip -r "$DIST_DIR/$APP_NAME.zip" "$APP_NAME.app" >/dev/null

echo "Built app: $APP_BUNDLE"
echo "Zip for distribution: $DIST_DIR/$APP_NAME.zip"
