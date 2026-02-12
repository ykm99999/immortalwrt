#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 更新并安装 Feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 物理预设核心配置 (针对 25.12 架构)
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config

# 🎯 物理核心修复：将 128M 转换为字节纯数字（物理修复补丁）
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

# 🎯 物理核心修复：锁定 Rootfs 分区
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 🎯 物理覆盖设备定义文件
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
fi

# 3. 锁定配置并同步
make defconfig
make oldconfig
