#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a

rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config

[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config

# 🎯 物理修复 1：修正 Rootfs 分区大小单位（确保是纯数字）
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 🎯 物理修复 2：修正 Makefile 中可能的 128M 溢出
# 针对 mediatek/image/Makefile 或相关 mk 文件进行物理替换
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

mkdir -p "target/linux/mediatek/image"
[ -f "${SRC_DIR}/filogic.mk" ] && cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

mkdir -p "target/linux/mediatek/dts"
[ -f "${SRC_DIR}/mt7981b-sl3000-emmc.dts" ] && cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

make defconfig
echo "✅ 已物理修复 128M 语法错误并完成环境预设。"
