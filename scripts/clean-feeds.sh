#!/bin/bash
set -e

echo ">>> [SL3000 V31-Fixed] 修正环境与依赖..."

# --- 1. 定位资产 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 物理对齐与引用修复 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR/mediatek"

# 拷贝并解决 include 找不到头文件的问题
cp -f "$DTS_SRC" "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
ln -sf "$DTS_DEST_DIR"/*.dtsi "$DTS_DEST_DIR/mediatek/" 2>/dev/null || true

# --- 3. 覆盖设备定义 ---
[ -f "$MK_SRC" ] && cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 依赖项补课 (解决 jq/host 与 mt76 依赖) ---
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/feeds install jq

# --- 5. 配置校准 (防止 sed 报错) ---
touch .config
sed -i '/CONFIG_TARGET/d' .config
[ -f "$CONF_SRC" ] && cat "$CONF_SRC" >> .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} >> .config

make defconfig
