#!/bin/sh
set -e

echo "=== 🔍 profiles.json 设备注册检查（25.12 / 6.12） ==="

profile=$(find openwrt/bin/targets -name profiles.json | head -n 1)

if [ -z "$profile" ]; then
    echo "❌ profiles.json 未找到"
    exit 1
fi

echo "✔ profiles.json 存在: $profile"

if grep -q '"id": "mt7981b-sl-3000-emmc"' "$profile"; then
    echo "✔ 设备已注册 (mt7981b-sl-3000-emmc)"
else
    echo "❌ 设备未注册 (mt7981b-sl-3000-emmc)"
    exit 1
fi

echo "=== ✅ profiles.json 检查完成 ==="
