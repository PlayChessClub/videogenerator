#!/bin/zsh
# ClipForge 构建脚本：swiftc 编译 + .app 组装 + ad-hoc 签名 + hdiutil 打包 dmg
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

echo "==> [5/8] 生成 dmg 窗口背景图（1x + 2x hidpi tiff）"
BG2X="$BUILD_DIR/dmg_bg@2x.png"
BG1X="$BUILD_DIR/dmg_bg.png"
BG_TIFF="$BUILD_DIR/dmg_bg.tiff"
if [ ! -x "$BUILD_DIR/makebg" ]; then
  DEVELOPER_DIR=$DEV_DIR swiftc -sdk "$SDK" -target arm64-apple-macosx11.0 -O \
    Tools/MakeDMGBackground.swift -o "$BUILD_DIR/makebg" 2>/dev/null || true
fi
[ -x "$BUILD_DIR/makebg" ] && "$BUILD_DIR/makebg" "$BG2X" 2>/dev/null || true
# 下采样得到 1x；Retina 上从 2160→1080，极其锐利
[ -f "$BG2X" ] && sips --resampleWidth 1080 "$BG2X" --out "$BG1X" >/dev/null 2>&1 || true
# 合成 hidpi tiff：Finder 在 Retina 屏自动选 2x representation
if [ -f "$BG1X" ] && [ -f "$BG2X" ]; then
  tiffutil -cathidpicheck "$BG1X" "$BG2X" -out "$BG_TIFF" 2>/dev/null \
    || cp "$BG2X" "$BG_TIFF"
elif [ -f "$BG2X" ]; then
  cp "$BG2X" "$BG_TIFF"
fi

echo "==> [6/8] 准备 dmg 内容（App + Applications 软链 + 隐藏背景图）"
STAGING="$BUILD_DIR/dmg_staging"; rm -rf "$STAGING"; mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"
[ -f "$BG_TIFF" ] && cp "$BG_TIFF" "$STAGING/.background/background.tiff"
DMG_RW="$BUILD_DIR/ClipForge-${VERSION}-rw.dmg"
DMG="$BUILD_DIR/ClipForge-${VERSION}.dmg"
rm -f "$DMG_RW" "$DMG"
# 先确保同名卷未挂载
hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null || true
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDRW -fs HFS+ "$DMG_RW" >/dev/null

echo "==> [7/8] 挂载 dmg 并用 AppleScript 美化 Finder 窗口"
ATTACH=$(hdiutil attach "$DMG_RW" -nobrowse -readwrite -mountpoint "/Volumes/$APP_NAME" 2>&1)
echo "$ATTACH" | grep -q "/Volumes/$APP_NAME" || { echo "  · 挂载失败：$ATTACH"; exit 1; }
sleep 1

cat > "$BUILD_DIR/dmg_layout.applescript" <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        delay 0.5
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {180, 110, 1260, 770}
        delay 0.5
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        try
            set background picture of theViewOptions to POSIX file "/Volumes/$APP_NAME/.background/background.tiff"
        end try
        try
            set position of item "ClipForge.app" of container window to {300, 300}
        end try
        try
            set position of item "Applications" of container window to {780, 300}
        end try
        try
            set position of item ".background" of container window to {2000, 2000}
        end try
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# AppleScript 偶发受残留挂载或 Finder 状态干扰：失败时重挂载 + 重试一次
ran_as=1
if ! osascript "$BUILD_DIR/dmg_layout.applescript" 2>"$BUILD_DIR/osascript.log"; then
    ran_as=0
    echo "  · AppleScript 首次失败，重挂载后重试…"
    hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null || true
    sleep 1
    hdiutil attach "$DMG_RW" -nobrowse -readwrite -mountpoint "/Volumes/$APP_NAME" >/dev/null 2>&1 || \
      hdiutil attach "$DMG_RW" -nobrowse -readwrite >/dev/null 2>&1
    sleep 2
    if osascript "$BUILD_DIR/dmg_layout.applescript" 2>"$BUILD_DIR/osascript.log"; then
        ran_as=1
    fi
fi
if [ "$ran_as" -eq 1 ]; then
    echo "  · 窗口布局已应用（隐藏工具栏 + 图标位置 + 玻璃背景）"
else
    echo "  · AppleScript 美化失败（详见 $BUILD_DIR/osascript.log），以默认外观继续"
fi

echo "==> [8/8] 卸载并压缩 dmg"
# 等 .DS_Store 落盘
sleep 2
hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null \
  || hdiutil detach "/Volumes/$APP_NAME" -force 2>/dev/null || true
sleep 1
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$DMG_RW" "$BG2X" "$BG1X" "$BG_TIFF" "$BUILD_DIR/dmg_layout.applescript"
rm -rf "$STAGING"

# 可选签名身份：若机器已有 Developer ID 证书则用正式签名，否则 ad-hoc
#   SIGN_APP  : Developer ID Application 证书名/ID（签名 .app 与 .dmg）
#   SIGN_PKG  : Developer ID Installer 证书名/ID（签名 .pkg）
#   置空则降级 ad-hoc
SIGN_APP="${SIGN_APP:-}"
SIGN_PKG="${SIGN_PKG:-}"

echo "==> [9/9] 打包 .pkg 安装包（dmg + pkg 双格式）"
if [ -n "$SIGN_PKG" ]; then
    PKG_SIGN_FLAG=(--sign "$SIGN_PKG")
else
    PKG_SIGN_FLAG=()
fi
PKG="$BUILD_DIR/ClipForge-${VERSION}.pkg"
rm -f "$PKG"
# 组件方式安装到 /Applications（不强制 root；避免每次都输管理员密码）
pkgbuild --component "$APP" --install-location /Applications \
    "${PKG_SIGN_FLAG[@]}" \
    "$PKG" 2>"$BUILD_DIR/pkgbuild.log" || {
      echo "  · pkgbuild 失败，见 $BUILD_DIR/pkgbuild.log"; cat "$BUILD_DIR/pkgbuild.log"; exit 1; }
[ -f "$PKG" ] || { echo "  · pkg 打包失败，见 $BUILD_DIR/pkgbuild.log"; exit 1; }
rm -f "$BUILD_DIR/pkgbuild.log"

echo "==> 完成"
ls -lh "$DMG" "$PKG" "$APP/Contents/MacOS/$APP_NAME"
