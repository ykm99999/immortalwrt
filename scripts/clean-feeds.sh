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
printf 'src-git routing https://github.com/openwrt/routing.git\n' >> feeds.conf.default

# 2. [物理补齐源码包 - 彻底修复 404 与解压失败]
mkdir -p dl
if [ ! -f "dl/u-boot-2024.10.tar.bz2" ]; then
    printf "正在物理获取 U-Boot 2024.10 源码包...\n"
    wget -t 3 -T 30 -O dl/u-boot-2024.10.tar.bz2 https://ftp.denx.de/pub/u-boot/u-boot-2024.10.tar.bz2
fi

# 3. [环境刷新]
rm -rf feeds/
./scripts/feeds update -a
./scripts/feeds install -a -f

# 4. 🔥 [U-Boot 2024.10 物理外科手术 - 结构死锁版]
UB_MK="package/boot/uboot-mediatek/Makefile"
rm -rf package/boot/uboot-mediatek/patches
mkdir -p package/boot/uboot-mediatek

printf 'include $(TOPDIR)/rules.mk\ninclude $(INCLUDE_DIR)/kernel.mk\n' > "$UB_MK"
printf 'PKG_NAME:=uboot-mediatek\nPKG_VERSION:=2024.10\nPKG_RELEASE:=1\n' >> "$UB_MK"
printf 'PKG_SOURCE:=u-boot-$(PKG_VERSION).tar.bz2\n' >> "$UB_MK"
printf 'PKG_HASH:=f7869ef42674681617260f8f1723467f9345095e26915152865d18d4076e03f0\n' >> "$UB_MK"
printf 'PKG_BUILD_DIR:=$(BUILD_DIR)/u-boot-$(PKG_VERSION)\n' >> "$UB_MK"
printf 'include $(INCLUDE_DIR)/package.mk\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc\n  SECTION:=boot\n  CATEGORY:=Boot Loaders\n  TITLE:=U-Boot for SL3000\n  DEPENDS:=@TARGET_mediatek\nendef\n' >> "$UB_MK"

printf 'define Build/Prepare\n\t$(Build/Prepare/Default)\n' >> "$UB_MK"
printf '\techo "#define CFG_SYS_INIT_RAM_ADDR 0x40000000" >> $(PKG_BUILD_DIR)/include/configs/mt7981.h\n' >> "$UB_MK"
printf '\techo "#define CFG_SYS_INIT_RAM_SIZE 0x00040000" >> $(PKG_BUILD_DIR)/include/configs/mt7981.h\n' >> "$UB_MK"
printf '\techo "#define CFG_SYS_INIT_SP_ADDR (CFG_SYS_INIT_RAM_ADDR + CFG_SYS_INIT_RAM_SIZE - 0x10)" >> $(PKG_BUILD_DIR)/include/configs/mt7981.h\n' >> "$UB_MK"
printf '\tcp $(PKG_BUILD_DIR)/arch/arm/dts/mt7981-emmc-rfb.dts $(PKG_BUILD_DIR)/arch/arm/dts/mt7981-sl3000-emmc.dts\n' >> "$UB_MK"
printf '\tsed -i "s/mt7981-rfb.dtb/mt7981-rfb.dtb mt7981-sl3000-emmc.dtb/" $(PKG_BUILD_DIR)/arch/arm/dts/Makefile\n' >> "$UB_MK"
printf '\tcp $(PKG_BUILD_DIR)/configs/mt7981_emmc_rfb_defconfig $(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf '\tsed -i "s/DEFAULT_DEVICE_TREE=.*/DEFAULT_DEVICE_TREE=\\"mt7981-sl3000-emmc\\"/" $(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"

printf 'define Build/Compile\n\t$(MAKE) -C $(PKG_BUILD_DIR) mt7981_sl3000_emmc_defconfig\n\t$(MAKE) -C $(PKG_BUILD_DIR) olddefconfig\n\t$(MAKE) -C $(PKG_BUILD_DIR) CROSS_COMPILE=$(TARGET_CROSS) DEVICE_DTS=mt7981-sl3000-emmc\nendef\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc/install\n\t$(INSTALL_DIR) $(1)\n\t$(CP) $(PKG_BUILD_DIR)/u-boot.bin $(1)/u-boot-sl3000.bin\nendef\n' >> "$UB_MK"
printf '$(eval $(call BuildPackage,uboot-mediatek-mt7981-sl3000-emmc))\n' >> "$UB_MK"

# 5. [内核 DTS 物理注入]
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
done

# 6. [完整物理配置文件注入 - 严格执行数值与双引号指令]
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_TARGET_MULTI_PROFILE=n\n' >> .config
printf 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_immortalwrt_mediatek-filogic-openwrt_one=n\n' >> .config
printf 'CONFIG_TARGET_KERNEL_PARTSIZE=131072\n' >> .config
printf 'CONFIG_TARGET_ROOTFS_PARTSIZE=1048576\n' >> .config
printf 'CONFIG_TARGET_ROOTFS_PARTNAME="rootfs"\n' >> .config
printf 'CONFIG_TARGET_ROOTFS_SQUASHFS=y\n' >> .config
printf 'CONFIG_TARGET_IMAGES_GZIP=y\n' >> .config
printf 'CONFIG_PACKAGE_arm-trusted-firmware-mediatek=y\n' >> .config
printf 'CONFIG_ARM_TRUSTED_FIRMWARE_MEDIATEK_mt7981-emmc-ddr3=y\n' >> .config
printf 'CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_kmod-mmc=y\n' >> .config
printf 'CONFIG_PACKAGE_kmod-sdhci-mtk=y\n' >> .config
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
