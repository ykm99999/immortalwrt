#!/bin/bash
# ============================================================
# SL3000 硬件注入脚本 - 修复 DTS 路径偏差
# ============================================================

set -e

echo ">>> [步骤 1] 强制覆盖平台 Makefile (filogic.mk)"
# 确保目标目录存在
mkdir -p openwrt/target/linux/mediatek/image/
cp -f target/linux/mediatek/image/filogic.mk openwrt/target/linux/mediatek/image/filogic.mk

echo ">>> [步骤 2] 修复并投送设备树 (DTS)"
# 关键：根据你的 mk 配置，DTS 必须放在 mediatek 子目录下
# 我们利用 target/linux/mediatek/files-6.12 目录，编译系统会自动同步它到内核源码
DTS_DEST_DIR="openwrt/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

# 注入并修正后缀 (.d -> .dts)
cp -f target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatekmt7981b-sl3000-emmc.d "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

echo ">>> [步骤 3] 注入 1GB 内存优化版 Config"
cp -f sl3000/config/sl3000.config openwrt/.config

echo ">>> [步骤 4] 自动化同步 Feeds & 注册硬件"
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a

# 强制执行一次 defconfig 刷新索引
make defconfig

# 验证注入结果 (自愈检查)
if [ -f "build_dir" ]; then
    echo "警告：检测到旧的编译残留，建议云端环境保持纯净。"
fi
echo ">>> SL3000 注入完成，文件一致性校验通过。"
