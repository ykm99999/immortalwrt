#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 物理铲平已知冲突源
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

# 2. 🔥 物理大扫除：剔除所有非路由器相关的源（物理移除 telephony/video/routing/management/games）
if [ -f "feeds.conf.default" ]; then
    sed -i '/video/d' feeds.conf.default
    sed -i '/telephony/d' feeds.conf.default
    sed -i '/routing/d' feeds.conf.default
    sed -i '/management/d' feeds.conf.default
fi

# 3. 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 4. [.config] 物理锁定逻辑（改用 printf 规避 EOF）
rm -f .config
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_atf-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_TARGET_KERNEL_PARTSIZE=128\n' >> .config
printf 'CONFIG_TARGET_ROOTFS_PARTSIZE=1024\n' >> .config
printf 'CONFIG_PACKAGE_kmod-mmc=y\n' >> .config
printf 'CONFIG_PACKAGE_kmod-mtk-sd=y\n' >> .config
printf 'CONFIG_PACKAGE_kmod-fs-f2fs=y\n' >> .config
printf 'CONFIG_PACKAGE_f2fs-tools=y\n' >> .config
printf 'CONFIG_PACKAGE_f2fsck=y\n' >> .config
printf 'CONFIG_PACKAGE_parted=y\n' >> .config
printf 'CONFIG_PACKAGE_lsblk=y\n' >> .config
printf 'CONFIG_PACKAGE_blkid=y\n' >> .config
printf 'CONFIG_PACKAGE_block-mount=y\n' >> .config
printf 'CONFIG_PACKAGE_kmod-zram=y\n' >> .config
printf 'CONFIG_PACKAGE_zram-swap=y\n' >> .config
printf 'CONFIG_PACKAGE_luci=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-theme-bootstrap=y\n' >> .config
printf 'CONFIG_PACKAGE_curl=y\n' >> .config
printf 'CONFIG_PACKAGE_wget-ssl=y\n' >> .config
printf 'CONFIG_PACKAGE_htop=y\n' >> .config
printf 'CONFIG_PACKAGE_nano=y\n' >> .config

# 5. DTS 注入逻辑（物理对齐日志确认的 files-6.12 路径）
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981-rfb.dts"
    fi
done

# 6. filogic.mk 生成（🔥 路由器专属补丁：注入 ARTIFACTS 强制开启 FIP 打包物理通道）
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
