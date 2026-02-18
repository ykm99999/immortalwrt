#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 🔥 [旗舰级清理] 物理铲平已知所有上游冲突与冗余
# 彻底爆破 package 目录下所有可能干扰 MT7981 编译的第三方冲突源
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils
rm -rf package/utils/pcat-manager
rm -rf package/libs/libsemanage
rm -rf package/feeds/packages/onionshare-cli
rm -rf package/feeds/luci/luci-app-advanced-reboot

# 2. 🔥 [源头封锁] 物理修改 Feed 仓库，实现真正的“专属白名单”
# 物理移除：电信级、视频级、非对称路由级等 4 大臃肿 Feed，确保源码树仅存路由器核心
if [ -f "feeds.conf.default" ]; then
    sed -i '/video/d' feeds.conf.default
    sed -i '/telephony/d' feeds.conf.default
    sed -i '/routing/d' feeds.conf.default
    sed -i '/management/d' feeds.conf.default
fi

# 3. 物理执行定向安装
./scripts/feeds update -a
./scripts/feeds install -a

# 4. 🔥 [结构死锁] 旗舰级 .config 物理配置 (使用 printf 强制写入)
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
printf 'CONFIG_PACKAGE_block-mount=y\n' >> .config
printf 'CONFIG_PACKAGE_luci=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-theme-bootstrap=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-i18n-base-zh-cn=y\n' >> .config

# 5. [路径物理对齐] DTS 注入逻辑 (针对 files-6.12 工业路径)
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981-rfb.dts"
    fi
done

# 6. 🔥 [旗舰产物定义] 重构 filogic.mk 并注入强制 ARTIFACTS
MK_TARGET="target/linux/mediatek/image/filogic.mk"
printf 'define Device/3000-emmc\n' > filogic.mk.final
printf '  DEVICE_VENDOR := SL\n' >> filogic.mk.final
printf '  DEVICE_MODEL := 3000-eMMC\n' >> filogic.mk.final
printf '  DEVICE_DTS := mt7981b-3000-emmc\n' >> filogic.mk.final
printf '  DEVICE_DTS_DIR := $(DTS_DIR)/mediatek\n' >> filogic.mk.final
printf '  KERNEL_SIZE := 134217728\n' >> filogic.mk.final
printf '  IMAGE_SIZE := 1207959552\n' >> filogic.mk.final
printf '  KERNEL := kernel-bin | lzma | uImage lzma\n' >> filogic.mk.final
printf '  DEVICE_PACKAGES := kmod-mmc kmod-mtk-sd kmod-fs-f2fs f2fs-tools f2fsck block-mount uboot-mediatek-mt7981-sl3000-emmc atf-mediatek-mt7981-sl3000-emmc\n' >> filogic.mk.final
printf '  IMAGES := sysupgrade.bin\n' >> filogic.mk.final
printf '  IMAGE/sysupgrade.bin := append-kernel | pad-to 134217728 | append-rootfs | append-metadata | check-size\n' >> filogic.mk.final
printf '  ARTIFACTS := fip.bin\n' >> filogic.mk.final
printf '  ARTIFACT/fip.bin := mt7981-bl31-uboot sl3000-emmc\n' >> filogic.mk.final
printf 'endef\n' >> filogic.mk.final
printf 'TARGET_DEVICES += 3000-emmc\n' >> filogic.mk.final
cp -fv "filogic.mk.final" "$MK_TARGET"
