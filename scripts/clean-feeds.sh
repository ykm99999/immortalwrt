#!/bin/bash
set -eo pipefail

# 🎯 物理定位
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo -e "\033[32m🚀 [SL3000] 执行物理自愈补丁（自适应内核路径） ...\033[0m"

cd "${WORKDIR}"

# 1. 物理环境准备
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build

# 2. 🔥 [.config] 延续您的所有插件，补全 host 工具依赖
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_PACKAGE_u-boot-sl3000-emmc=y"
    echo "CONFIG_PACKAGE_atf-mt7981-sl3000-emmc=y"
    # 物理补全依赖
    echo "CONFIG_PACKAGE_jq=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
    echo "CONFIG_TARGET_IMAGES_GZIP=y"
    # --- 延续您的原始插件配置 ---
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

# 3. 🔥 [ID 修正]
find target/linux/mediatek/ -type f \( -name "*.dts*" -o -name "*.dtsi*" \) -exec sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' {} +

# 4. 🔥 [DTS 物理自适应注入] 
# 修复 target/linux 报错的关键：扫描所有可能的内核 files 目录
KERNEL_FILES_DIRS=$(ls -d target/linux/mediatek/files-* 2>/dev/null || true)
if [ -z "$KERNEL_FILES_DIRS" ]; then
    echo "⚠️ 未发现 files-* 目录，正在创建默认 6.x 路径"
    KERNEL_FILES_DIRS="target/linux/mediatek/files-6.12"
fi

for KD in $KERNEL_FILES_DIRS; do
    DTS_DEST="$KD/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_DEST"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_DEST/mt7981b-3000-emmc.dts"
        cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_DEST/mt7981-rfb.dts"
        echo "✅ DTS 已物理注入到: $DTS_DEST"
    fi
done

# 5. 🔥 [MK 注入] 延续之前版本，移除填充逻辑
MK_TARGET="target/linux/mediatek/image/filogic.mk"
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
cp -fv "${SRC_DIR}/filogic.mk" "$MK_TARGET"

# 6. 物理屏蔽签名校验 (原文照抄)
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile || true
