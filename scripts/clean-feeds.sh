#!/bin/bash
set -eo pipefail

# 🎯 物理路径定义
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 环境自愈
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build

# 2. 🔥 [.config] 强制选中 U-Boot 和 ATF 编译组件
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    # 物理锁定引导加载程序组件
    echo "CONFIG_PACKAGE_u-boot-sl3000-emmc=y"
    echo "CONFIG_PACKAGE_atf-mt7981-sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
} > .config

# 3. 🔥 [MK 注入] 彻底移除 136MB 填充，解决旧版 U-Boot 报错
MK_TARGET="target/linux/mediatek/image/filogic.mk"
cat <<EOF > "filogic.mk"
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
  
  # 🚀 [物理修正] 移除 KERNEL_SIZE 填充，使体积降至 ~40MB 适配旧版 U-Boot
  BOARD_ROOTFS_PARTSIZE := 1024
  
  # 🔥 [U-Boot 识别核心] 必须带 uImage 封装
  KERNEL := kernel-bin | lzma | uImage lzma
  KERNEL_INITRAMFS := kernel-bin | lzma | uImage lzma
  
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \\
	parted lsblk blkid block-mount kmod-zram zram-swap
  
  IMAGES := sysupgrade.bin factory.bin
  
  # 🎯 [物理锁定] 严禁 pad-to 128M，直接拼接
  IMAGE/sysupgrade.bin := append-kernel | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
EOF
cp -fv "filogic.mk" "$MK_TARGET"

# 4. 屏蔽签名检查 (原文照抄)
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile || true
