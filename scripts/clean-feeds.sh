#!/bin/bash
set -eo pipefail

# 🎯 物理定位：脚本在 scripts/ 下，仓库根目录就是 ..
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo -e "\033[32m🚀 [SL3000] 执行三件套物理对齐：scripts/clean-feeds.sh 运行中...\033[0m"

cd "${WORKDIR}"

# 1. 物理环境准备 (延续成功案例原文)
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build

# 2. 🔥 [.config] 严格原文照抄你提供的 24 行核心配置
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
    echo "CONFIG_TARGET_IMAGES_GZIP=y"
    echo "CONFIG_PACKAGE_kmod-mmc=y"
    echo "CONFIG_PACKAGE_kmod-sdhci-mtk=y"
    echo "CONFIG_PACKAGE_kmod-fs-f2fs=y"
    echo "CONFIG_PACKAGE_f2fs-tools=y"
    echo "CONFIG_PACKAGE_f2fsck=y"
    echo "CONFIG_PACKAGE_parted=y"
    echo "CONFIG_PACKAGE_lsblk=y"
    echo "CONFIG_PACKAGE_blkid=y"
    echo "CONFIG_PACKAGE_block-mount=y"
    echo "CONFIG_PACKAGE_kmod-zram=y"
    echo "CONFIG_PACKAGE_zram-swap=y"
    echo "CONFIG_PACKAGE_luci=y"
    echo "CONFIG_PACKAGE_luci-theme-bootstrap=y"
    echo "CONFIG_PACKAGE_curl=y"
    echo "CONFIG_PACKAGE_wget-ssl=y"
    echo "CONFIG_PACKAGE_htop=y"
    echo "CONFIG_PACKAGE_nano=y"
} > .config

# 3. 🔥 [ID 修正] 延续地毯式替换逻辑
find target/linux/mediatek/ -type f \( -name "*.dts*" -o -name "*.dtsi*" \) -exec sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' {} +

# 4. 🔥 [DTS 注入] 物理适配 25.12 路径 (files-6.12)
# 🎯 物理源：从仓库根目录 ${SRC_DIR} 读取，不准换位置
DTS_PATH_A="target/linux/mediatek/dts"
DTS_PATH_B="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_PATH_A" "$DTS_PATH_B"
if [ -f "${SRC_DIR}/mt7981b-sl3000-emmc.dts" ]; then
    cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "$DTS_PATH_A/"
    cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "$DTS_PATH_B/"
fi

# 5. 🔥 [MK 注入] 延续锁定 1024MB 逻辑
# 🎯 物理源：从仓库根目录 ${SRC_DIR} 读取
mkdir -p target/linux/mediatek/image
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" target/linux/mediatek/image/
    sed -i 's/BOARD_ROOTFS_PARTSIZE := .*/BOARD_ROOTFS_PARTSIZE := 1024/g' target/linux/mediatek/image/filogic.mk || true
fi

# 6. 物理屏蔽逻辑 (原文照抄成功案例)
[ -f "include/image.mk" ] && sed -i 's/$(STAGING_DIR_HOST)\/bin\/pad-to/append-string/g' include/image.mk || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile || true

echo -e "\033[32m✅ 路径 scripts/clean-feeds.sh 及三件套物理源已完全闭环复刻。\033[0m"
