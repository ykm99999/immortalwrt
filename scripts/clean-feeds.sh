#!/bin/bash
set -e

echo ">>> [SL3000 V31.0] 修正路径对齐..."

# --- 1. 定位资产 (使用环境变量，确保稳健) ---
# 这些变量由 GitHub Actions 传入
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 物理对齐 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

# 统一引用格式，确保 DTC 能找到头文件
sed -e 's/#include <mediatek\/mt7981.dtsi>/#include "mt7981b.dtsi"/g' \
    -e 's/#include "mediatek\/mt7981.dtsi"/#include "mt7981b.dtsi"/g' \
    -e 's/#include <mediatek\/mt7981b.dtsi>/#include "mt7981b.dtsi"/g' \
    "$DTS_SRC" > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# --- 3. 覆盖设备定义 ---
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 强制开启打包必要配置 ---
# 注意：这里用 cat 覆盖，防止 .config 里的旧架构干扰
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
} >> .config

# --- 5. Feeds 更新 ---
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig
