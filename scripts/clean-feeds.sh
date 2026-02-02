#!/bin/bash
# ============================================================
# SL3000 工厂级修复脚本 (针对 Kernel 6.12 路径纠偏)
# ============================================================

set -e

echo ">>> [1/4] 环境预处理与路径对齐..."
TOPDIR=$(pwd)/openwrt
# 目标路径：6.12 内核强制要求在 dts/mediatek 子目录下编译
DTS_DEST_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$TOPDIR/$DTS_DEST_DIR"

echo ">>> [2/4] 注入 DTS 并执行全链路 Include 修正..."
# 逻辑：
# 1. 将 #include "mt7981.dtsi" 修正为 <mediatek/mt7981.dtsi>
# 2. 将 #include "mt7981b.dtsi" 修正为 <mediatek/mt7981b.dtsi>
# 这样即使没有相对路径，编译器也能通过全局搜索路径找到基础文件
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatekmt7981b-sl3000-emmc.d" \
    > "$TOPDIR/$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

echo ">>> [3/4] 强制覆盖平台 Makefile (filogic.mk)..."
mkdir -p "$TOPDIR/target/linux/mediatek/image/"
cp -f "target/linux/mediatek/image/filogic.mk" "$TOPDIR/target/linux/mediatek/image/filogic.mk"

# 注入 .config
if [ -f "sl3000/config/sl3000.config" ]; then
    cp -f "sl3000/config/sl3000.config" "$TOPDIR/.config"
fi

echo ">>> [4/4] Feeds 同步与硬件索引注册..."
cd "$TOPDIR"
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig

# 最终自检
if grep -q "sl3000-emmc" ".config"; then
    echo "SUCCESS: SL3000 硬件链路已打通！"
else
    echo "ERROR: 硬件定义未生效，请检查 filogic.mk" && exit 1
fi
