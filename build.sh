#!/bin/zsh
# ClipForge 构建脚本：swiftc 编译 + .app 组装 + ad-hoc 签名 + hdiutil 打包 dmg
set -e
cd "$(dirname "$0")"

APP_NAME="ClipForge"
BUNDLE_ID="com.clipforge.app"
VERSION="1.0.0"
BUILD_DIR="build"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
TARGET="arm64-apple-macosx26.0"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> [1/6] 编译 $APP_NAME（Swift / arm64 / macOS 26）"
rm -rf "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
DEVELOPER_DIR=/Library/Developer/CommandLineTools swiftc \
  -sdk "$SDK" -target "$TARGET" -O \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  Sources/*.swift

echo "==> [2/6] 生成 Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME · AI 视频编辑助手</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>ClipForge · 基于阿里云 DashScope（cosyvoice-v3.5-plus / wan2.6-i2v）</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key><true/>
    <key>NSAllowsArbitraryLoadsForMedia</key><true/>
  </dict>
</dict>
</plist>
PLIST

echo "==> [3/6] 生成应用图标"
ICON_TMP="$BUILD_DIR/icon_1024.png"
# 用 Swift 小工具绘制图标（避免依赖 PyObjC）
if [ ! -x "$BUILD_DIR/makeicon" ]; then
  DEVELOPER_DIR=/Library/Developer/CommandLineTools swiftc \
    -sdk "$SDK" -target arm64-apple-macosx26.0 -O \
    Tools/MakeIcon.swift -o "$BUILD_DIR/makeicon" 2>/dev/null || true
fi
[ -x "$BUILD_DIR/makeicon" ] && "$BUILD_DIR/makeicon" "$ICON_TMP" 2>/dev/null || true
if [ -f "$ICON_TMP" ]; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"; rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for sz in 16 32 64 128 256 512; do
    sips -z $sz $sz "$ICON_TMP" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null 2>&1 || true
    d=$((sz*2)); sips -z $d $d "$ICON_TMP" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1 || true
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null \
    || cp "$ICON_TMP" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> [4/6] ad-hoc 代码签名"
codesign --force --deep --sign - "$APP" 2>/dev/null
codesign --verify --verbose=1 "$APP" 2>&1 | tail -1

echo "==> [5/6] 打包 dmg"
STAGING="$BUILD_DIR/dmg_staging"; rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"
DMG="$BUILD_DIR/ClipForge-${VERSION}.dmg"; rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "==> [6/6] 完成"
ls -lh "$DMG" "$APP/Contents/MacOS/$APP_NAME"
