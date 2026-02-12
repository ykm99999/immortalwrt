#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 物理预设 25.12 基础配置
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config

# 🎯 物理核心修复 1：将所有 128M 转换为纯数字，防止 Bash 算术溢出报错
# 这个补丁必须在 defconfig 之前执行，覆盖所有 mk 文件
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

# 🎯 物理核心修复 2：同步 Rootfs 分区大小
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 预置 Makefile
[ -f "${SRC_DIR}/filogic.mk" ] && cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

make defconfig
