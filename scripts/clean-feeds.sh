#!/bin/bash
set -eo pipefail

REPO_ROOT="${GITHUB_WORKSPACE}"
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}/custom-config"

cd "${WORKDIR}"

# 1. 清理冲突包
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils
rm -rf package/utils/pcat-manager

# 2. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 写入 .config
rm -f .config
cat > .config << EOF
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
CONFIG_PACKAGE_kmod-mmc=y
CONFIG_PACKAGE_kmod-mtk-sd=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_f2fsck=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_kmod-zram=y
CONFIG_PACKAGE_zram-swap=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
EOF

# 4. 🔥 绝对正确路径：25.12 + 内核 6.12
DTS_DEST="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "${DTS_DEST}"
cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "${DTS_DEST}/"

# 5. 覆盖 filogic.mk
MK_TARGET="target/linux/mediatek/image/filogic.mk"
cat > "${MK_TARGET}" << EOF
define Device/3000-emmc
  DEVICE_VENDOR := SL
  DEVICE_MODEL := 3000-eMMC
  DEVICE_ALT0_VENDOR := SL
  DEVICE_ALT0_MODEL := SL3000
  SUPPORTED_DEVICES := sl,3000-emmc
  DEVICE_DTS := mt7981b-3000-emmc
  DEVICE_DTS_DIR := \$(DTS_DIR)/mediatek
  KERNEL_SIZE := 128M
  IMAGE_SIZE := 1152M
  KERNEL := kernel-bin | lzma | append-dtb | lzma
  DEVICE_PACKAGES := kmod-mmc kmod-mtk-sd kmod-fs-f2fs f2fs-tools f2fsck \
    parted lsblk blkid block-mount kmod-zram zram-swap
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := append-kernel | pad-to 128M | append-rootfs | append-metadata | check-size
endef
TARGET_DEVICES += 3000-emmc
EOF

echo -e "\033[32m✅ 25.12 + 6.12 内核适配完成 ✅\033[0m"
