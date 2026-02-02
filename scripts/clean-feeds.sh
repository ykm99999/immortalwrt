#!/bin/bash
set -e

echo ">>> [SL3000 工厂级注入] 正在对齐 1GB RAM + 128GB eMMC 硬件定义..."

TOPDIR=$(pwd)/openwrt
# 目标路径：内核 6.12 强制要求在 mediatek 子目录下编译
DEST_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$TOPDIR/$DEST_DIR"

# 1. 注入 DTS 并执行全链路修正
# A. 修正 include 引用方式
# B. 确保 1GB 内存 (1024MB) 定义正确
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/reg = <0 0x40000000 0 0x20000000>;/reg = <0 0x40000000 0 0x40000000>;/g' \
    "target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatekmt7981b-sl3000-emmc.d" \
    > "$TOPDIR/$DEST_DIR/mt7981b-sl3000-emmc.dts"

# 2. 强制覆盖 Makefile 定义 (使用你提供的包含 GPT/GL-Metadata 的版本)
mkdir -p "$TOPDIR/target/linux/mediatek/image/"
cp -f "target/linux/mediatek/image/filogic.mk" "$TOPDIR/target/linux/mediatek/image/filogic.mk"

# 3. 注入编译配置并开启 eMMC 支持
cp -f "sl3000/config/sl3000.config" "$TOPDIR/.config"
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> "$TOPDIR/.config" # 设置 1GB 根分区预留

# 4. 同步 Feeds
cd "$TOPDIR"
./scripts/feeds update -a && ./scripts/feeds install -a

# 5. 注册硬件到索引
make defconfig

echo ">>> 注入成功。DTS 已修正为: $DEST_DIR/mt7981b-sl3000-emmc.dts"
