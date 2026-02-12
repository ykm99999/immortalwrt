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

# 🎯 [核心补丁：128M 转换] 物理修复算术溢出错误
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

# 🎯 [核心补丁：分区对齐] 强制同步 Rootfs 分区大小
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 🎯 [核心补丁：设备定义] 物理覆盖 filogic.mk
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
fi

# 3. 锁定配置并同步（解决 config out of sync 警告）
make defconfig
make oldconfig
