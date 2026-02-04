#!/bin/bash
set -e

echo ">>> [SL3000 V33.2] 正在延续资产合并逻辑..."

# --- 1. 定位资产 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 目录对齐 (延续之前的注入逻辑) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"

mkdir -p "$DTS_DEST_DIR/mediatek"
cp -f "$DTS_SRC" "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
# 建立引用链接，彻底解决编译时的 Fatal error
ln -sf "$DTS_DEST_DIR"/*.dtsi "$DTS_DEST_DIR/mediatek/" 2>/dev/null || true

# --- 3. 设备 Makefile 覆盖 ---
[ -f "$MK_SRC" ] && cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 依赖项安装 (解决 jq/host 警告) ---
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/feeds install jq

# --- 5. 配置校准 (核心修复：防止 sed 报错) ---
# 先确保 .config 存在，否则 sed 会因找不到文件导致脚本中断
touch .config
# 清理可能导致架构干扰的旧 Target 选项
sed -i '/CONFIG_TARGET/d' .config

# 合并您的预设配置
[ -f "$CONF_SRC" ] && cat "$CONF_SRC" >> .config

# 强制注入打包必需的 Target 关键参数
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} >> .config

# 最终补全配置
make defconfig
