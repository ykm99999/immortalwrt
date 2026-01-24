#!/bin/sh
set -e

echo "=== 🔍 检查 SL3000 eMMC 设备 Profile（profiles.json） ==="

TARGET_DIR="openwrt/bin/targets/mediatek/filogic"
PROFILES_JSON="$TARGET_DIR/profiles.json"
DEVICE_ID="mt7981b-sl3000-emmc"

#########################################
# 1. 检查 profiles.json 是否存在
#########################################

if [ ! -f "$PROFILES_JSON" ]; then
    echo "❌ 未找到 profiles.json：$PROFILES_JSON"
    exit 1
fi

echo "✔ 找到 profiles.json：$PROFILES_JSON"

#########################################
# 2. 检查设备是否已注册
#########################################

if ! grep -q "\"$DEVICE_ID\"" "$PROFILES_JSON"; then
    echo "❌ 设备未在 profiles.json 中注册：$DEVICE_ID"
    exit 1
fi

echo "✔ 设备已在 profiles.json 中注册：$DEVICE_ID"

#########################################
# 3. 检查固件镜像是否存在
#########################################

FW_PATTERN="$TARGET_DIR/*${DEVICE_ID}*sysupgrade*.bin"

if ls $FW_PATTERN >/dev/null 2>&1; then
    echo "✔ 找到固件镜像："
    ls -lh $FW_PATTERN
else
    echo "❌ 未找到匹配设备的 sysupgrade 固件：$FW_PATTERN"
    exit 1
fi

echo "=== ✅ profiles.json 与固件产物检查通过 ==="
