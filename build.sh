#!/bin/zsh
# ClipForge 构建脚本：swiftc 编译 + .app 组装 + 签名 + pkgbuild 打包 .pkg
# （2026-09-09 起：安装包只出 .pkg，dmg 流程已退役）
set -e
cd "$(dirname "$0")"

APP_NAME="ClipForge"
BUNDLE_ID="com.clipforge.app"
VERSION="1.6.1"
MIN_OS="11.0"
BUILD_DIR="build"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
DEV_DIR=/Library/Developer/CommandLineTools
APP="$BUILD_DIR/$APP_NAME.app"

# 可选正式签名：机器有 Developer ID 证书时通过环境变量传入，否则 ad-hoc
#   SIGN_APP : Developer ID Application 证书（签 .app）
#   SIGN_PKG : Developer ID Installer 证书（签 .pkg）
SIGN_APP="${SIGN_APP:-}"
SIGN_PKG="${SIGN_PKG:-}"

echo "==> [1/5] 编译 $APP_NAME（通用二进制 arm64 + x86_64，最低 macOS $MIN_OS）"
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

echo "==> [2/5] 生成 Info.plist"
BUILD_NUMBER=$(($(date +%s) % 100000))
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>$APP_NAME</string>
	<key>CFBundleDisplayName</key><string>$APP_NAME</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleExecutable</key><string>$APP_NAME</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSHumanReadableCopyright</key>
	<string>基于阿里云 DashScope 多模态模型

· 语音合成：cosyvoice-v3.5-plus
· 声音克隆：voice-enrollment
· 文生视频：wan2.6-t2v / wan2.7-t2v
· 图生视频：wan2.6-i2v / wan2.7-i2v / wan2.6-i2v-flash
· 文生图：  qwen-image-2.0[-pro] / wan2.7-image[-pro]

© ClipForge · 仅作个人/内部使用</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key><true/>
		<key>NSAllowsArbitraryLoadsForMedia</key><true/>
	</dict>
</dict>
</plist>
PLIST

echo "==> [3/5] 生成应用图标"
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

echo "==> [4/5] 代码签名"
if [ -n "$SIGN_APP" ]; then
  echo "  · 使用正式证书: $SIGN_APP"
  codesign --force --deep --sign "$SIGN_APP" "$APP" 2>/dev/null
else
  echo "  · ad-hoc 签名（未配置 SIGN_APP）"
  codesign --force --deep --sign - "$APP" 2>/dev/null
fi
codesign --verify --verbose=1 "$APP" 2>&1 | tail -1

echo "==> [5/5] 打包 .pkg 安装包（安装到 /Applications）"
if [ -n "$SIGN_PKG" ]; then
  echo "  · 使用正式证书: $SIGN_PKG"
  PKG_SIGN_FLAG=(--sign "$SIGN_PKG")
else
  echo "  · 未签名 pkg（未配置 SIGN_PKG）"
  PKG_SIGN_FLAG=()
fi
PKG="$BUILD_DIR/ClipForge-${VERSION}.pkg"
rm -f "$PKG"
pkgbuild --component "$APP" --install-location /Applications \
    "${PKG_SIGN_FLAG[@]}" \
    "$PKG" 2>"$BUILD_DIR/pkgbuild.log" || {
      echo "  · pkgbuild 失败，见 $BUILD_DIR/pkgbuild.log"; cat "$BUILD_DIR/pkgbuild.log"; exit 1; }
[ -f "$PKG" ] || { echo "  · pkg 打包失败，见 $BUILD_DIR/pkgbuild.log"; exit 1; }
rm -f "$BUILD_DIR/pkgbuild.log"

echo "==> 完成"
ls -lh "$PKG" "$APP/Contents/MacOS/$APP_NAME"
