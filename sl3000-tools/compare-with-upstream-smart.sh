#!/bin/sh
set -e

echo "=== 🔍 智能对比：本地 SL3000 三件套 vs 上游 ImmortalWrt 25.12（平台级） ==="

UPSTREAM_REPO="https://github.com/immortalwrt/immortalwrt.git"
UPSTREAM_BRANCH="openwrt-25.12"
TMP_DIR="$(mktemp -d)"

LOCAL_MK="target/linux/mediatek/image/filogic.mk"
LOCAL_DTS="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"

UPSTREAM_MK="$TMP_DIR/target/linux/mediatek/image/filogic.mk"
UPSTREAM_DTSI="$TMP_DIR/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/mt7981.dtsi"
UPSTREAM_DRV="$TMP_DIR/target/linux/mediatek/files-6.12/drivers"

echo "→ 克隆上游仓库：$UPSTREAM_REPO ($UPSTREAM_BRANCH)"
git clone --depth=1 -b "$UPSTREAM_BRANCH" "$UPSTREAM_REPO" "$TMP_DIR" >/dev/null 2>&1
echo "✔ 上游源码已克隆"

#########################################
# 1. 对比 filogic.mk（平台级字段变化）
#########################################

echo
echo "=== 🔍 对比 filogic.mk（平台级字段变化） ==="

if [ ! -f "$LOCAL_MK" ]; then
    echo "❌ 本地 MK 缺失：$LOCAL_MK"
    exit 1
fi

if [ ! -f "$UPSTREAM_MK" ]; then
    echo "❌ 上游 MK 缺失：$UPSTREAM_MK"
    exit 1
fi

# 提取字段（不包含你的自定义设备段）
grep -E '^[[:space:]]*[A-Z0-9_]+[[:space:]]*:=' "$LOCAL_MK" | sort > /tmp/local_fields.txt
grep -E '^[[:space:]]*[A-Z0-9_]+[[:space:]]*:=' "$UPSTREAM_MK" | sort > /tmp/upstream_fields.txt

echo
echo "→ 字段新增（上游有，本地没有）"
comm -13 /tmp/local_fields.txt /tmp/upstream_fields.txt || true

echo
echo "→ 字段缺失（本地有，上游没有）"
comm -23 /tmp/local_fields.txt /tmp/upstream_fields.txt || true

echo
echo "→ 字段差异（字段名相同但内容不同）"
diff -u "$UPSTREAM_MK" "$LOCAL_MK" | grep -E '^[+-][[:space:]]*[A-Z0-9_]+[[:space:]]*:=' || true

#########################################
# 2. 对比 mt7981.dtsi（SoC 级变化）
#########################################

echo
echo "=== 🔍 对比 mt7981.dtsi（SoC 级变化） ==="

if [ -f "$UPSTREAM_DTSI" ]; then
    diff -u "$UPSTREAM_DTSI" "$LOCAL_DTS" || true
else
    echo "⚠ 上游缺失 mt7981.dtsi（不影响你的设备）"
fi

#########################################
# 3. 对比 mediatek 驱动目录（驱动级变化）
#########################################

echo
echo "=== 🔍 对比 mediatek 驱动目录（驱动级变化） ==="

if [ -d "$UPSTREAM_DRV" ]; then
    echo "→ 上游驱动文件变化："
    diff -qr "$UPSTREAM_DRV" "$TMP_DIR" 2>/dev/null || true
else
    echo "⚠ 上游缺失 mediatek 驱动目录（可能版本差异）"
fi

#########################################
# 4. 提示：你的设备是自定义设备
#########################################

echo
echo "⚠ 提示：你的设备（mt7981b-sl3000-emmc）是自定义设备，上游不会包含你的 DTS/MK，这是正常情况。"
echo "✔ 智能对比仅监控平台级变化（filogic / mt7981 / mediatek 驱动）"

echo
echo "=== ✅ 智能对比完成（未修改任何本地文件） ==="
echo "临时目录：$TMP_DIR"
