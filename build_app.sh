#!/bin/bash
# MacToolkit - macOS .app 打包脚本
# 用法: ./build_app.sh [--open]

set -euo pipefail

APP_NAME="MacToolkit"
BUNDLE_NAME="MacToolkit"
BUILD_CONFIG="release"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_DIR="$SCRIPT_DIR/dist/$APP_NAME.app"

echo "🛑 正在关闭已运行的 $APP_NAME..."
# 尝试优雅关闭
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 0.5
# 强制结束残留进程
killall "$BUNDLE_NAME" 2>/dev/null || true

# SPM 资源 bundle 路径（arm64 架构）
RESOURCE_BUNDLE="$BUILD_DIR/arm64-apple-macosx/$BUILD_CONFIG/${BUNDLE_NAME}_${BUNDLE_NAME}.bundle"

echo "🔨 编译 $APP_NAME ($BUILD_CONFIG)..."
cd "$SCRIPT_DIR"
swift build -c "$BUILD_CONFIG" 2>&1

# 获取编译产物路径
BINARY_PATH="$BUILD_DIR/arm64-apple-macosx/$BUILD_CONFIG/$BUNDLE_NAME"
if [ ! -f "$BINARY_PATH" ]; then
    BINARY_PATH="$BUILD_DIR/$BUILD_CONFIG/$BUNDLE_NAME"
fi
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ 编译失败: 找不到二进制 $BINARY_PATH"
    exit 1
fi

echo "📦 组装 .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 复制二进制
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$BUNDLE_NAME"

# 复制 Info.plist
cp "$SCRIPT_DIR/Sources/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# 复制 SPM 资源 bundle（含猫咪动画等资源）
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
    echo "  ✅ 已添加资源 bundle: $(basename "$RESOURCE_BUNDLE")"
else
    echo "  ⚠️  未找到资源 bundle: $RESOURCE_BUNDLE"
fi

# 如果有图标文件，复制图标
if [ -f "$SCRIPT_DIR/Sources/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Sources/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    echo "  ✅ 已添加 App 图标"
else
    echo "  ℹ️  无 AppIcon.icns，使用默认图标"
fi

# 签名（ad-hoc）
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

APP_SIZE=$(du -sh "$APP_DIR" | cut -f1)
echo ""
echo "✅ 打包完成!"
echo "   📍 $APP_DIR"
echo "   📏 大小: $APP_SIZE"
echo ""

echo "🚀 正在重新打开 $APP_NAME..."
open "$APP_DIR"
