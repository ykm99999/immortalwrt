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

# 2. [物理源码补齐]
mkdir -p dl
[ ! -f "dl/u-boot-2024.10.tar.bz2" ] && wget -O dl/u-boot-2024.10.tar.bz2 https://ftp.denx.de/pub/u-boot/u-boot-2024.10.tar.bz2

# 3. [环境刷新]
rm -rf feeds/
./scripts/feeds update -a
./scripts/feeds install -a -f

# 4. 🔥 [物理外科手术：SL3000 唯一化处理]
# 逻辑：不删除文件内容，但物理强制 Target 只包含我们的设备
MK_FILE="target/linux/mediatek/image/filogic.mk"
if [ -f "$MK_FILE" ]; then
    printf "正在物理锁定 SL3000 编译目标...\n"
    # 物理注入 SL3000 设备块到文件末尾，确保它存在
    [ -f "${SRC_DIR}/custom-config/filogic.mk" ] && cat "${SRC_DIR}/custom-config/filogic.mk" >> "$MK_FILE"
fi

# 5. 🔥 [U-Boot 2024.10 物理注入 - 结构死锁]
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

# 6. [内核 DTS 注入]
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
done

# 7. [物理配置锁定 - 强制启用 SL3000]
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_TARGET_KERNEL_PARTSIZE=131072\n' >> .config
printf 'CONFIG_TARGET_ROOTFS_PARTSIZE=1048576\n' >> .config
printf 'CONFIG_TARGET_ROOTFS_PARTNAME="rootfs"\n' >> .config
# 驱动与应用层
printf 'CONFIG_PACKAGE_arm-trusted-firmware-mediatek=y\nCONFIG_ARM_TRUSTED_FIRMWARE_MEDIATEK_mt7981-emmc-ddr3=y\nCONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_kmod-mmc=y\nCONFIG_PACKAGE_kmod-sdhci-mtk=y\nCONFIG_PACKAGE_kmod-fs-f2fs=y\nCONFIG_PACKAGE_f2fs-tools=y\nCONFIG_PACKAGE_f2fsck=y\nCONFIG_PACKAGE_parted=y\nCONFIG_PACKAGE_lsblk=y\nCONFIG_PACKAGE_blkid=y\nCONFIG_PACKAGE_block-mount=y\nCONFIG_PACKAGE_kmod-zram=y\nCONFIG_PACKAGE_zram-swap=y\nCONFIG_PACKAGE_luci=y\nCONFIG_PACKAGE_luci-theme-bootstrap=y\nCONFIG_PACKAGE_curl=y\nCONFIG_PACKAGE_wget-ssl=y\nCONFIG_PACKAGE_htop=y\nCONFIG_PACKAGE_nano=y\n' >> .config
