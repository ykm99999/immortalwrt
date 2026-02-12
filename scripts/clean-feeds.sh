#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}/custom-config"

echo -e "\033[32m🚀 [SL3000] 执行 25.12 物理对齐：锁定 ID 并修正内核路径...\033[0m"

cd "${WORKDIR}"

# 1. 物理重建 .config (完全照抄你的 24 行核心配置)
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

# 2. 修正 ID 冲突 (承袭成功案例逻辑)
find target/linux/mediatek/ -type f \( -name "*.dts*" -o -name "*.dtsi*" \) -exec sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' {} +

# 3. 物理注入 DTS (核心修正：指向 files-6.12)
DTS_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DIR"
if [ -f "${SRC_DIR}/mt7981b-sl3000-emmc.dts" ]; then
    cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "$DTS_DIR/"
    sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' "$DTS_DIR/mt7981b-sl3000-emmc.dts"
fi

# 4. 物理注入 MK (承袭成功案例逻辑)
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" target/linux/mediatek/image/
    sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' target/linux/mediatek/image/filogic.mk
    sed -i 's/sl3000-emmc/3000-emmc/g' target/linux/mediatek/image/filogic.mk
    sed -i 's/BOARD_ROOTFS_PARTSIZE := .*/BOARD_ROOTFS_PARTSIZE := 1024/g' target/linux/mediatek/image/filogic.mk
    sed -i 's/pad-to/append-string/g' target/linux/mediatek/image/filogic.mk
fi

# 5. 屏蔽签名与 pad-to 报错 (承袭成功案例逻辑)
[ -f "include/image.mk" ] && sed -i 's/$(STAGING_DIR_HOST)\/bin\/pad-to/append-string/g' include/image.mk
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile
