#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a

# 1. 物理强置基础配置
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config
[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config

# 2. 🎯 物理强占 files-6.12 路径 (最高优先级)
# 将你刚才提供的 DTS 内容物理覆盖掉官方的参考板定义
DTS_DEST="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "$DTS_DEST/mt7981-rfb.dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "$DTS_DEST/mt7981b-sl3000-emmc.dts"

# 3. 物理修复 128M 语法溢出
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

# 4. 物理预置设备定义 (Makefile)
[ -f "${SRC_DIR}/filogic.mk" ] && cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

make defconfig
echo "✅ 终极物理覆盖已完成。"
