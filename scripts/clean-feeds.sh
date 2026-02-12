#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 更新并安装 Feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 物理预设核心配置
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config

# 🎯 [物理修复] 128M 转换为纯数字（物理补丁，防止 Makefile 算术溢出）
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

# 🎯 [物理修复] 锁定 Rootfs 分区大小 (1024MB)
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 🎯 [物理修复] 覆盖设备定义
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
fi

# 3. 锁定配置
make defconfig
make oldconfig
