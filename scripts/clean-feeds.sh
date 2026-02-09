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
# 🎯 永久补丁：强制 1024M 分区大小
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 物理预置 DTS
mkdir -p "target/linux/mediatek/dts"
[ -f "${SRC_DIR}/mt7981b-sl3000-emmc.dts" ] && cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

# 物理预置 mk 补丁
mkdir -p "target/linux/mediatek/image"
[ -f "${SRC_DIR}/filogic.mk" ] && cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

make defconfig
echo "✅ 构建环境物理补丁应用成功。"
