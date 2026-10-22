#!/usr/bin/env bash
# 一键编译 → 启动模拟器 → 安装 → 拉起 → 截图
#
# 用法：
#   bash iOS/scripts/run_sim.sh              # 自动挑一台可用 iPhone 模拟器
#   bash iOS/scripts/run_sim.sh "iPhone 17 Pro"
#
# 前置：macOS + Xcode 15 以上（不需要开发者账号，模拟器构建无需签名）

set -euo pipefail

BUNDLE_ID="com.wuyong.allclear"
cd "$(dirname "$0")/.."

# 1. 选设备：优先用显式传入的，否则取当前 Xcode 里第一台可用 iPhone
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices available \
    | grep -E '^\s+iPhone' \
    | head -n 1 \
    | sed -E 's/^[[:space:]]*(.*) \(([0-9A-F-]+)\).*/\1/')
fi

if [ -z "$DEVICE" ]; then
  echo "没有找到可用的 iPhone 模拟器，请先在 Xcode > Window > Devices 里下载一个 iOS 运行时" >&2
  exit 1
fi
echo "==> 使用模拟器：$DEVICE"

# 2. 生成工程（仓库已提交 .xcodeproj，装了 xcodegen 才顺手刷新）
if command -v xcodegen >/dev/null 2>&1; then
  echo "==> xcodegen generate"
  xcodegen generate
else
  echo "==> 未安装 xcodegen，直接使用已提交的 AllClear.xcodeproj（brew install xcodegen 可自动刷新）"
fi

# 3. 编译
echo "==> 编译（Debug / 模拟器）"
xcodebuild \
  -project AllClear.xcodeproj \
  -scheme AllClear \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="build/Build/Products/Debug-iphonesimulator/AllClear.app"
[ -d "$APP" ] || { echo "编译产物不存在：$APP" >&2; exit 1; }

# 4. 启动 / 安装 / 运行
echo "==> 启动模拟器"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

echo "==> 等待模拟器就绪"
for _ in $(seq 1 30); do
  if xcrun simctl list devices booted | grep -q "$DEVICE"; then break; fi
  sleep 1
done

echo "==> 安装并启动"
xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"

sleep 3
mkdir -p build
xcrun simctl io booted screenshot build/shot.png
echo "==> 完成，截图：$PWD/build/shot.png"
