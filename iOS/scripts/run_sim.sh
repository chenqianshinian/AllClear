#!/usr/bin/env bash
# 一键编译 → 启动模拟器 → 安装 → 拉起
#
# 用法：
#   bash iOS/scripts/run_sim.sh                       # 默认 iPhone 16 Pro
#   bash iOS/scripts/run_sim.sh "iPhone 15"           # 指定机型
#
# 前置：macOS + Xcode 15 以上 + xcodegen（brew install xcodegen）

set -euo pipefail

DEVICE="${1:-iPhone 16 Pro}"
BUNDLE_ID="com.wuyong.allclear"

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 xcodegen，请先执行：brew install xcodegen" >&2
  exit 1
fi

echo "==> 生成 Xcode 工程"
xcodegen generate

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

echo "==> 启动模拟器"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

# 等模拟器真正就绪，避免 install 报 "device not booted"
echo "==> 等待模拟器就绪"
for _ in $(seq 1 30); do
  if xcrun simctl list devices booted | grep -q "$DEVICE"; then break; fi
  sleep 1
done

echo "==> 安装并启动"
xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"

sleep 2
mkdir -p build
xcrun simctl io booted screenshot build/shot.png
echo "==> 完成，截图已保存到 $PWD/build/shot.png"
