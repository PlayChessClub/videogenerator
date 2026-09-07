#!/bin/zsh
# ClipForge 构建脚本：swiftc 编译 + .app 组装 + ad-hoc 签名 + hdiutil 打包 dmg
set -e
cd "$(dirname "$0")"

APP_NAME="ClipForge"
BUNDLE_ID="com.clipforge.app"
VERSION="1.1.0"
MIN_OS="11.0"
BUILD_DIR="build"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
DEV_DIR=/Library/Developer/CommandLineTools
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> [1/6] 编译 $APP_NAME（通用二进制 arm64 + x86_64，最低 macOS $MIN_OS）"
rm -rf "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
rm -f "$BUILD_DIR/bin_arm64" "$BUILD_DIR/bin_x86_64"

DEVELOPER_DIR=$DEV_DIR swiftc -sdk "$SDK" -target arm64-apple-macosx${MIN_OS} -O \
  -o "$BUILD_DIR/bin_arm64" Sources/*.swift 2>&1 | grep -v warning || true
[ -f "$BUILD_DIR/bin_arm64" ] || { echo "arm64 编译失败"; exit 1; }

# Intel x86_64：SDK 仍含 x86_64 切片；失败则降级为 arm64-only
if DEVELOPER_DIR=$DEV_DIR swiftc -sdk "$SDK" -target x86_64-apple-macosx${MIN_OS} -O \
  -o "$BUILD_DIR/bin_x86_64" Sources/*.swift 2>/dev/null; then
  echo "  · 合并 arm64 + x86_64 通用二进制"
  lipo -create "$BUILD_DIR/bin_arm64" "$BUILD_DIR/bin_x86_64" -output "$APP/Contents/MacOS/$APP_NAME"
else
  echo "  · x86_64 编译不可用，仅产出 arm64（Apple Silicon，Big Sur+）"
  cp "$BUILD_DIR/bin_arm64" "$APP/Contents/MacOS/$APP_NAME"
fi
chmod +x "$APP/Contents/MacOS/$APP_NAME"
file "$APP/Contents/MacOS/$APP_NAME"

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
  <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
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
