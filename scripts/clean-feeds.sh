#!/bin/bash
# ============================================================
# SL3000 V28.0：官方路径对齐版 [彻底修复 Include 报错]
# ============================================================
set -e

echo ">>> [SL3000 V28.0] 启动注入任务..."

# --- 1. 定位资产 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 预处理：对齐官方引用格式 ---
# 官方 RFB 源码证明了同目录下引用 "mt7981b.dtsi" 是可行的
# 我们将你的 DTS 引用统一修改为双引号本地引用
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [对齐] 正在转换 DTS 引用为官方 RFB 格式..."
sed -e 's/#include <mediatek\/mt7981.dtsi>/#include "mt7981b.dtsi"/g' \
    -e 's/#include "mediatek\/mt7981.dtsi"/#include "mt7981b.dtsi"/g' \
    -e 's/#include <mediatek\/mt7981b.dtsi>/#include "mt7981b.dtsi"/g' \
    -e 's/#include "mt7981.dtsi"/#include "mt7981b.dtsi"/g' \
    "$DTS_SRC" | tr -d '\r' > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# --- 3. 固件 Makefile 与配置合并 ---
# 注入 eMMC 和 交换机 驱动支持
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools kmod-mt7531/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# 生成基础配置
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# --- 4. Feeds 同步 ---
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig

echo "✅ [配置完成] DTS 已放置于待命目录，准备进行物理拦截。"
