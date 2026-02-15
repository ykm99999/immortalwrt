#!/bin/bash
set -eo pipefail

# 🎯 物理定位
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo -e "\033[32m🚀 [SL3000] 正在执行 136MB U-Boot 物理对齐脚本 ...\033[0m"

cd "${WORKDIR}"

# 1. 物理环境准备 (原文照抄)
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build

# 2. 🔥 [.config] 锁定物理分区尺寸与核心组件
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

# 3. 🔥 [ID 修正] 物理全量替换，确保识别为 sl,3000-emmc
find target/linux/mediatek/ -type f \( -name "*.dts*" -o -name "*.dtsi*" \) -exec sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' {} +

# 4. 🔥 [DTS 注入] 覆盖内核目录
DTS_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DIR"
if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
    cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_DIR/mt7981b-3000-emmc.dts"
    cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_DIR/mt7981-rfb.dts"
fi

# 5. 🔥 [MK 注入] 严禁偷工减料，强制写入 U-Boot 构建逻辑
MK_TARGET="target/linux/mediatek/image/filogic.mk"
# 我们直接在脚本内物理构造 Device 定义，确保 100% 准确
cat <<EOF > "${SRC_DIR}/filogic.mk"
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
  KERNEL_SIZE := 131072k
  BOARD_ROOTFS_PARTSIZE := 1024
  KERNEL := kernel-bin | lzma | uImage lzma
  KERNEL_INITRAMFS := kernel-bin | lzma | uImage lzma
  DEVICE_PACKAGES := kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools f2fsck \\
	parted lsblk blkid block-mount kmod-zram zram-swap
  IMAGES := sysupgrade.bin factory.bin
  IMAGE/sysupgrade.bin := append-kernel | pad-to \$\$(KERNEL_SIZE) | append-rootfs | pad-rootfs | append-metadata
  IMAGE/factory.bin := append-kernel | pad-to \$\$(KERNEL_SIZE) | append-rootfs | pad-rootfs
endef
TARGET_DEVICES += sl3000-emmc
EOF

cp -fv "${SRC_DIR}/filogic.mk" "$MK_TARGET"

# 6. 物理屏蔽签名校验 (原文照抄)
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile || true

echo -e "\033[32m✅ 脚本物理对齐完成：uImage 封装与 136MB 填充已就绪。\033[0m"
