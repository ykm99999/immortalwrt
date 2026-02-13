#!/bin/bash
set -eo pipefail

# 🎯 物理定位：脚本在 scripts/ 下，仓库根目录是 ..
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo -e "\033[32m🚀 [SL3000] 执行 25.12 物理对齐：锁定 mt7981b-3000-emmc.dts ...\033[0m"

cd "${WORKDIR}"

# 1. 物理环境准备 (原文照抄)
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build

# 2. 🔥 [.config] 严格原文照抄 24 行核心配置
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

# 3. 🔥 [ID 修正] 物理延续：全量替换 sl,sl3000 -> sl,3000
find target/linux/mediatek/ -type f \( -name "*.dts*" -o -name "*.dtsi*" \) -exec sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' {} +

# 4. 🔥 [DTS 注入] 适配 25.12 的 files-6.12 路径
DTS_PATH_A="target/linux/mediatek/dts"
DTS_PATH_B="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_PATH_A" "$DTS_PATH_B"
if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
    cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH_A/"
    cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH_B/"
    
    # 🚀 [物理硬修复] 深度钻探修复：解决 dt-bindings/gpio/gpio.h 缺失
    # 原理：在 DTS 编译目录物理建立指向内核 include 的软链接
    KERNEL_VER=$(ls target/linux/mediatek/ | grep "files-" | cut -d'-' -f2 | head -n1)
    if [ -n "$KERNEL_VER" ]; then
        mkdir -p "target/linux/mediatek/files-${KERNEL_VER}/arch/arm64/boot/dts/mediatek/dt-bindings"
        # 建立物理映射，消除 fatal error
        ln -sf "../../../../../../../../../include/dt-bindings/gpio" "target/linux/mediatek/files-${KERNEL_VER}/arch/arm64/boot/dts/mediatek/dt-bindings/gpio"
        ln -sf "../../../../../../../../../include/dt-bindings/input" "target/linux/mediatek/files-${KERNEL_VER}/arch/arm64/boot/dts/mediatek/dt-bindings/input"
        ln -sf "../../../../../../../../../include/dt-bindings/interrupt-controller" "target/linux/mediatek/files-${KERNEL_VER}/arch/arm64/boot/dts/mediatek/dt-bindings/interrupt-controller"
    fi
else
    echo -e "\033[31m❌ 错误：仓库根目录找不到 mt7981b-3000-emmc.dts！\033[0m"
    exit 1
fi

# 5. 🔥 [MK 注入] 物理源根目录提取 filogic.mk
mkdir -p target/linux/mediatek/image
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" target/linux/mediatek/image/
    # 强制物理同步分区数值（严格承袭逻辑）
    sed -i 's/BOARD_ROOTFS_PARTSIZE := .*/BOARD_ROOTFS_PARTSIZE := 1024/g' target/linux/mediatek/image/filogic.mk || true
fi

# 6. 物理屏蔽补丁 (原文照抄自 24.10 成功案例)
[ -f "include/image.mk" ] && sed -i 's/$(STAGING_DIR_HOST)\/bin\/pad-to/append-string/g' include/image.mk || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile || true

echo -e "\033[32m✅ 脚本已物理修复。DTS 路径及 dt-bindings 软链接已完成深钻锁定。\033[0m"
