#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 物理铲平导致扫描失败的源头
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils
rm -rf package/utils/pcat-manager

# 2. 定向拉取核心 feed
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 🔥 [.config] 物理延续您的核心配置
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_PACKAGE_u-boot-sl3000-emmc=y"
    echo "CONFIG_PACKAGE_atf-mt7981-sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    # --- 物理延续原始插件清单 ---
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

# 4. 🔥 [DTS/MK 注入] 严格承袭逻辑
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981b-3000-emmc.dts"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981-rfb.dts"
done

MK_TARGET="target/linux/mediatek/image/filogic.mk"
cat <<EOF > "filogic.mk.final"
define Device/sl3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000 (eMMC)
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  DEVICE_ALT0_VARIANT := eMMC 1024MB GPT-Fixed
  DEVICE_COMPAT_VERSION := 1.0
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := \$(DTS_DIR)/mediatek
  SUPPORTED_DEVICES := sl,3000-emmc sl,sl3000-emmc mediatek,mt7981
  BOARD_ROOTFS_PARTSIZE := 1024
  KERNEL := kernel-bin | lzma | uImage lzma
  KERNEL_INITRAMFS := kernel-bin | lzma | uImage lzma
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \\
	parted lsblk blkid block-mount kmod-zram zram-swap
  IMAGES := sysupgrade.bin factory.bin
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
EOF
cp -fv "filogic.mk.final" "$MK_TARGET"
