#!/bin/bash
set -e

echo ">>> [SL3000 V24.0] 启动终极物理合并注入..."

# --- 1. 定位资产 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. 物理合并 DTS (彻底消灭 #include 依赖) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [彻底解决] 正在物理合并 .dtsi 内容到主 DTS..."

# 创建一个临时工作文件
cat "$DTS_SRC" > dts_temp.dts

# 物理展开 mt7981.dtsi 和 mt7981b.dtsi (如果存在于内核目录中)
# 我们直接从内核源码路径读取这些基础定义并替换 include 行
if [ -f "$DTS_DEST_DIR/mt7981.dtsi" ]; then
    sed -i "/mt7981.dtsi/r $DTS_DEST_DIR/mt7981.dtsi" dts_temp.dts
    sed -i "/mt7981.dtsi/d" dts_temp.dts
fi

if [ -f "$DTS_DEST_DIR/mt7981b.dtsi" ]; then
    sed -i "/mt7981b.dtsi/r $DTS_DEST_DIR/mt7981b.dtsi" dts_temp.dts
    sed -i "/mt7981b.dtsi/d" dts_temp.dts
fi

# 剩下的系统级头文件（如 gpio.h）保留尖括号，内核 DTC 能通过内置路径找到
cp dts_temp.dts "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 注册 Makefile
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动与配置延续 ---
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# Feeds 刷新
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig
echo "✅ [任务完成] V24.0 物理合并成功！"
