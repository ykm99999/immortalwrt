#!/bin/sh
set -e

echo "=== 🔍 profiles.json 设备注册检查（25.12 / 6.12） ==="

profile=$(find openwrt/bin/targets -name profiles.json | head -n 1)

if [ -z "$profile" ]; then
    echo "❌ profiles.json 未找到"
    exit 1
fi

echo "✔ profiles.json 存在: $profile"

DEVICE_ID="mt7981b-sl-3000-emmc"

if grep -q "\"id\": \"$DEVICE_ID\"" "$profile"; then
    echo "✔ 设备已注册 ($DEVICE_ID)"
else
    echo "❌ 设备未注册 ($DEVICE_ID)"
    exit 1
fi

echo "=== ✅ profiles.json 检查完成 ==="
