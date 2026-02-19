#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. [源头封锁]
rm -rf feeds.conf
printf 'src-git packages https://github.com/immortalwrt/packages.git\n' > feeds.conf.default
printf 'src-git luci https://github.com/immortalwrt/luci.git\n' >> feeds.conf.default

# 2. [物理清场]
rm -rf feeds/
./scripts/feeds update -a
./scripts/feeds install -a -f

# 3. 🔥 [物理预下载新版源码] 彻底解决 404
mkdir -p dl
wget -t 10 -T 15 https://github.com/u-boot/u-boot/archive/refs/tags/v2024.10.tar.gz -O dl/u-boot-2024.10.tar.gz
wget -t 10 -T 15 https://github.com/ARM-software/arm-trusted-firmware/archive/refs/tags/v2.12.tar.gz -O dl/atf-2.12.tar.gz

# 4. 🔥 [物理外科重写 - U-Boot] 抛弃 EOF 改用 printf
UB_MK="package/boot/uboot-mediatek/Makefile"
rm -rf package/boot/uboot-mediatek/patches
mkdir -p package/boot/uboot-mediatek

printf 'include $(TOPDIR)/rules.mk\n' > "$UB_MK"
printf 'include $(INCLUDE_DIR)/kernel.mk\n' >> "$UB_MK"
printf 'PKG_NAME:=uboot-mediatek\n' >> "$UB_MK"
printf 'PKG_VERSION:=2024.10\n' >> "$UB_MK"
printf 'PKG_RELEASE:=1\n' >> "$UB_MK"
printf 'PKG_SOURCE:=u-boot-$(PKG_VERSION).tar.gz\n' >> "$UB_MK"
printf 'PKG_BUILD_DIR:=$(BUILD_DIR)/u-boot-$(PKG_VERSION)\n' >> "$UB_MK"
printf 'PATCH_DIR:=\n' >> "$UB_MK"
printf 'include $(INCLUDE_DIR)/package.mk\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc\n' >> "$UB_MK"
printf '  SECTION:=boot\n' >> "$UB_MK"
printf '  CATEGORY:=Boot Loaders\n' >> "$UB_MK"
printf '  TITLE:=U-Boot for SL3000 (MT7981) eMMC\n' >> "$UB_MK"
printf '  DEPENDS:=@TARGET_mediatek\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"
printf 'define Build/Prepare\n' >> "$UB_MK"
printf '\t$(Build/Prepare/Default)\n' >> "$UB_MK"
printf '\trm -rf $(PKG_BUILD_DIR)/patches\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"
printf 'define Build/Compile\n' >> "$UB_MK"
printf '\t$(MAKE) -C $(PKG_BUILD_DIR) mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf '\t$(MAKE) -C $(PKG_BUILD_DIR) CROSS_COMPILE=$(TARGET_CROSS) DEVICE_DTS=mt7981-sl3000-emmc\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc/install\n' >> "$UB_MK"
printf '\t$(INSTALL_DIR) $(1)\n' >> "$UB_MK"
printf '\t$(CP) $(PKG_BUILD_DIR)/u-boot.bin $(1)/\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"
printf '$(eval $(call BuildPackage,uboot-mediatek-mt7981-sl3000-emmc))\n' >> "$UB_MK"

# 5. 🔥 [物理外科重写 - ATF] 抛弃 EOF 改用 printf
ATF_MK="package/boot/atf-mediatek/Makefile"
rm -rf package/boot/atf-mediatek/patches
mkdir -p package/boot/atf-mediatek

printf 'include $(TOPDIR)/rules.mk\n' > "$ATF_MK"
printf 'PKG_NAME:=atf-mediatek\n' >> "$ATF_MK"
printf 'PKG_VERSION:=2.12\n' >> "$ATF_MK"
printf 'PKG_RELEASE:=1\n' >> "$ATF_MK"
printf 'PKG_SOURCE:=atf-$(PKG_VERSION).tar.gz\n' >> "$ATF_MK"
printf 'PKG_BUILD_DIR:=$(BUILD_DIR)/arm-trusted-firmware-$(PKG_VERSION)\n' >> "$ATF_MK"
printf 'PATCH_DIR:=\n' >> "$ATF_MK"
printf 'include $(INCLUDE_DIR)/package.mk\n' >> "$ATF_MK"
printf 'define Package/atf-mediatek-mt7981-sl3000-emmc\n' >> "$ATF_MK"
printf '  SECTION:=boot\n' >> "$ATF_MK"
printf '  CATEGORY:=Boot Loaders\n' >> "$ATF_MK"
printf '  TITLE:=ATF for SL3000 (MT7981) eMMC\n' >> "$ATF_MK"
printf '  DEPENDS:=@TARGET_mediatek\n' >> "$ATF_MK"
printf 'endef\n' >> "$ATF_MK"
printf 'define Build/Prepare\n' >> "$ATF_MK"
printf '\t$(Build/Prepare/Default)\n' >> "$ATF_MK"
printf '\trm -rf $(PKG_BUILD_DIR)/patches\n' >> "$ATF_MK"
printf 'endef\n' >> "$ATF_MK"
printf 'define Build/Compile\n' >> "$ATF_MK"
printf '\t$(MAKE) -C $(PKG_BUILD_DIR) CROSS_COMPILE=$(TARGET_CROSS) PLAT=mt7981 all\n' >> "$ATF_MK"
printf 'endef\n' >> "$ATF_MK"
printf '$(eval $(call BuildPackage,atf-mediatek-mt7981-sl3000-emmc))\n' >> "$ATF_MK"

# 6. [物理修复] 冲突铲平 (承袭原文)
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils

# 7. [结构死锁] .config 物理配置 (改用 printf)
rm -f .config
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_atf-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_luci=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-theme-bootstrap=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-i18n-base-zh-cn=y\n' >> .config

# 8. [路径物理对齐] DTS 注入
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
done

# 9. [旗舰打包补丁] 重构 filogic.mk (改用 printf)
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
