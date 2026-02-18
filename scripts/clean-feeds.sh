#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 物理铲平冲突源
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils
rm -rf package/utils/pcat-manager
rm -rf package/libs/libsemanage
rm -rf package/feeds/luci/luci-app-advanced-reboot
rm -rf package/feeds/packages/onionshare-cli
rm -rf package/system/refpolicy
rm -rf package/system/selinux-policy

# 2. 🔥 物理修复：剔除不必要的 video feed（解决日志中 gzdoom/qt5 噪音）
if [ -f "feeds.conf.default" ]; then
    sed -i '/video/d' feeds.conf.default
fi

# 3. 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 4. [.config] 物理锁定逻辑（改用 echo 规避 EOF）
rm -f .config
echo "CONFIG_TARGET_mediatek=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y" >> .config
echo "CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y" >> .config
echo "CONFIG_PACKAGE_atf-mediatek-mt7981-sl3000-emmc=y" >> .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=128" >> .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config
echo "CONFIG_PACKAGE_kmod-mmc=y" >> .config
echo "CONFIG_PACKAGE_kmod-mtk-sd=y" >> .config
echo "CONFIG_PACKAGE_kmod-fs-f2fs=y" >> .config
echo "CONFIG_PACKAGE_f2fs-tools=y" >> .config
echo "CONFIG_PACKAGE_f2fsck=y" >> .config
echo "CONFIG_PACKAGE_parted=y" >> .config
echo "CONFIG_PACKAGE_lsblk=y" >> .config
echo "CONFIG_PACKAGE_blkid=y" >> .config
echo "CONFIG_PACKAGE_block-mount=y" >> .config
echo "CONFIG_PACKAGE_kmod-zram=y" >> .config
echo "CONFIG_PACKAGE_zram-swap=y" >> .config
echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_PACKAGE_luci-theme-bootstrap=y" >> .config
echo "CONFIG_PACKAGE_curl=y" >> .config
echo "CONFIG_PACKAGE_wget-ssl=y" >> .config
echo "CONFIG_PACKAGE_htop=y" >> .config
echo "CONFIG_PACKAGE_nano=y" >> .config

# 5. DTS 注入逻辑（物理对齐 files-6.12 路径）
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981-rfb.dts"
    fi
done

# 6. filogic.mk 生成（🔥 物理修复：注入 ARTIFACTS 强制触发 FIP/U-Boot 物理打包）
MK_TARGET="target/linux/mediatek/image/filogic.mk"
printf 'define Device/3000-emmc\n' > filogic.mk.final
printf '  DEVICE_VENDOR := SL\n' >> filogic.mk.final
printf '  DEVICE_MODEL := 3000-eMMC\n' >> filogic.mk.final
printf '  DEVICE_ALT0_VENDOR := SL\n' >> filogic.mk.final
printf '  DEVICE_ALT0_MODEL := SL3000\n' >> filogic.mk.final
printf '  SUPPORTED_DEVICES := sl,3000-emmc\n' >> filogic.mk.final
printf '  DEVICE_DTS := mt7981b-3000-emmc\n' >> filogic.mk.final
printf '  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek\n' >> filogic.mk.final
printf '  KERNEL_SIZE := 134217728\n' >> filogic.mk.final
printf '  IMAGE_SIZE := 1207959552\n' >> filogic.mk.final
printf '  KERNEL := kernel-bin | lzma | uImage lzma\n' >> filogic.mk.final
printf '  DEVICE_PACKAGES := kmod-mmc kmod-mtk-sd kmod-fs-f2fs f2fs-tools f2fsck parted lsblk blkid block-mount kmod-zram zram-swap uboot-mediatek-mt7981-sl3000-emmc atf-mediatek-mt7981-sl3000-emmc\n' >> filogic.mk.final
printf '  IMAGES := sysupgrade.bin\n' >> filogic.mk.final
printf '  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata | check-size\n' >> filogic.mk.final
printf '  ARTIFACTS := fip.bin\n' >> filogic.mk.final
printf '  ARTIFACT/fip.bin := mt7981-bl31-uboot sl3000-emmc\n' >> filogic.mk.final
printf 'endef\n' >> filogic.mk.final
printf 'TARGET_DEVICES += 3000-emmc\n' >> filogic.mk.final
cp -fv "filogic.mk.final" "$MK_TARGET"
