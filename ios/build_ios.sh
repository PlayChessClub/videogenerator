#!/bin/zsh
# ClipForge iOS 构建脚本：swiftc 编译（Core+App 单模块）→ .app 组装 → ad-hoc 签名 →（可选）装进模拟器
# 说明：Xcode 26.x 的 CLI 工具不再按旧式 plist 解析 project.pbxproj，手写的 xcodeproj 无法直接 xcodebuild。
# 本项目沿用 macOS 版 build.sh 的思路：直接用 swiftc 对模拟器 SDK 编译，再手工组装 .app，绕开 pbxproj 格式问题。
set -e
cd "$(dirname "$0")"

APP_NAME="ClipForgeiOS"
DISPLAY_NAME="ClipForge"
BUNDLE_ID="com.clipforge.ios"
VERSION="1.7.3"
MIN_OS="16.0"
TARGET="arm64-apple-ios${MIN_OS}-simulator"

SWIFTC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

BUILD_DIR="build_ios"
APP="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP" "$BUILD_DIR/bin"
mkdir -p "$APP" "$BUILD_DIR"

echo "==> [1/5] 编译 $APP_NAME（单模块：ClipForgeCore + 应用，目标 $TARGET）"
# 应用源引用了 `import ClipForgeCore`，但本构建把 Core 与应用编进同一模块，
# 故把应用 Sources 全部复制到临时目录并去掉该 import（源码本身保持不变，将来 xcodeproj 仍可用）
rm -rf "$BUILD_DIR/appsrc"
mkdir -p "$BUILD_DIR/appsrc"
for f in ClipForgeiOS/Sources/*.swift; do
  grep -v '^import ClipForgeCore' "$f" > "$BUILD_DIR/appsrc/$(basename "$f")"
done

$SWIFTC -sdk "$SDK" -target "$TARGET" \
  -module-name "$APP_NAME" \
  -O \
  -emit-executable \
  -o "$BUILD_DIR/bin" \
  ClipForgeCore/Sources/ClipForgeCore/*.swift "$BUILD_DIR/appsrc"/*.swift 2>&1 \
  | grep -v "warning:" || true
[ -f "$BUILD_DIR/bin" ] || { echo "编译失败"; exit 1; }
mv "$BUILD_DIR/bin" "$APP/$APP_NAME"
echo "  · 可执行文件: $(file "$APP/$APP_NAME" | cut -d: -f2-)"

echo "==> [2/5] 生成 Info.plist"
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
	<key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
	<key>CFBundleExecutable</key><string>$APP_NAME</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>$DISPLAY_NAME</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSRequiresIPhoneOS</key><true/>
	<key>MinimumOSVersion</key><string>$MIN_OS</string>
	<key>UILaunchScreen</key>
	<dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key><true/>
	</dict>
</dict>
</plist>
PLIST

echo "==> [3/5] 装入内置音色素材（VoiceSamples，随包只读；缺则跳过）"
if [ -d ../VoiceSamples ]; then
  rm -rf "$APP/VoiceSamples"
  cp -R ../VoiceSamples "$APP/VoiceSamples"
  echo "  · 已装入 $(ls ../VoiceSamples | wc -l | tr -d ' ') 个文件"
else
  echo "  · 未找到 ../VoiceSamples，跳过"
fi

echo "==> [4/5] ad-hoc 签名（模拟器无需正式证书）"
codesign --force --sign - "$APP" 2>&1 | tail -1 || true
codesign --verify --verbose=1 "$APP" 2>&1 | tail -1 || true

echo "==> [5/5] 构建完成: $APP"
ls -lh "$APP"

# 可选：装进模拟器并启动（传入 deploy 参数时）
if [ "$1" = "deploy" ]; then
  # 1) 找已启动的模拟器
  BOOTED=$(xcrun simctl list devices | awk -F'[()]' '/Booted/{print $2; exit}')
  if [ -z "$BOOTED" ]; then
    # 2) 找一台已存在的 iPhone/iPad（任意状态）直接 boot
    EXISTING=$(xcrun simctl list devices | awk -F'[()]' '/iPhone|iPad/{print $2; exit}')
    if [ -n "$EXISTING" ]; then
      xcrun simctl boot "$EXISTING" 2>/dev/null || true
      BOOTED="$EXISTING"
    else
      # 3) 没有就新建：自动选一个已装 runtime（不写死版本号）
      RUNTIME=$(xcrun simctl list runtimes 2>/dev/null | awk '/iOS .* is available/{print $NF; exit}')
      [ -z "$RUNTIME" ] && RUNTIME=$(xcrun simctl list runtimes 2>/dev/null | awk '/available/{print $NF; exit}')
      if [ -n "$RUNTIME" ]; then
        UDID=$(xcrun simctl create "ClipForgeTest" "iPhone 16" "$RUNTIME" 2>&1)
      else
        UDID=$(xcrun simctl create "ClipForgeTest" "iPhone 16" 2>&1)
      fi
      UDID=$(echo "$UDID" | grep -oE '[A-F0-9-]{36}' | head -1)
      xcrun simctl boot "$UDID"
      BOOTED="$UDID"
    fi
  fi
  echo "==> 部署到模拟器 $BOOTED"
  xcrun simctl install "$BOOTED" "$APP"
  xcrun simctl launch "$BOOTED" "$BUNDLE_ID"
fi
