#!/bin/sh
set -e

echo "=== 🔄 重建三件套（25.12 / Linux 6.12） ==="

# 按你确认的真实 DTS 路径（files-6.12）
rm -f target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts

# MK 与 CONFIG 路径保持不变
rm -f target/linux/mediatek/image/filogic.mk
rm -f .config

# 重新生成三件套
sh sl3000-tools/generate-three-piece.sh

echo "=== ✔ 三件套已重建 ==="
