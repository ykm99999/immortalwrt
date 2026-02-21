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

# 2. [物理对齐]
rm -rf feeds/
./scripts/feeds update -a
./scripts/feeds install -a -f

# 3. [物理源码锁定]
mkdir -p dl
curl -L --connect-timeout 20 --retry 5 "https://github.com/u-boot/u-boot/archive/refs/tags/v2024.10.tar.gz" -o "dl/u-boot-2024.10.tar.gz"

# 4. 🔥 [物理绝杀：Makefile 内部硬核注入]
UB_MK="package/boot/uboot-mediatek/Makefile"
rm -rf package/boot/uboot-mediatek/patches
mkdir -p package/boot/uboot-mediatek

printf 'include $(TOPDIR)/rules.mk\ninclude $(INCLUDE_DIR)/kernel.mk\n' > "$UB_MK"
printf 'PKG_NAME:=uboot-mediatek\nPKG_VERSION:=2024.10\nPKG_RELEASE:=1\n' >> "$UB_MK"
printf 'PKG_SOURCE:=u-boot-$(PKG_VERSION).tar.gz\n' >> "$UB_MK"
printf 'PKG_BUILD_DIR:=$(BUILD_DIR)/u-boot-$(PKG_VERSION)\n' >> "$UB_MK"
printf 'include $(INCLUDE_DIR)/package.mk\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc\n  SECTION:=boot\n  CATEGORY:=Boot Loaders\n  TITLE:=U-Boot for SL3000\n  DEPENDS:=@TARGET_mediatek\nendef\n' >> "$UB_MK"

printf 'define Build/Prepare\n\t$(Build/Prepare/Default)\n' >> "$UB_MK"
# A. 物理硬编码物理地址 (硬切预处理层)
printf '\techo "#define CFG_SYS_INIT_RAM_ADDR 0x40000000" >> $(PKG_BUILD_DIR)/include/configs/mt7981.h\n' >> "$UB_MK"
printf '\techo "#define CFG_SYS_INIT_RAM_SIZE 0x00040000" >> $(PKG_BUILD_DIR)/include/configs/mt7981.h\n' >> "$UB_MK"
printf '\techo "#define CFG_SYS_INIT_SP_ADDR (CFG_SYS_INIT_RAM_ADDR + CFG_SYS_INIT_RAM_SIZE - 0x10)" >> $(PKG_BUILD_DIR)/include/configs/mt7981.h\n' >> "$UB_MK"
# B. 🔥 物理定位补丁：使用绝对路径确保 DTS 抓取
printf '\tcp $(abspath $(TOPDIR)/../mt7981b-3000-emmc.dts) $(PKG_BUILD_DIR)/arch/arm/dts/mt7981-sl3000-emmc.dts\n' >> "$UB_MK"
# C. 物理注册编译目标 (强制修改源码 Makefile)
printf '\tsed -i "s/mt7981-rfb.dtb/mt7981-rfb.dtb mt7981-sl3000-emmc.dtb/" $(PKG_BUILD_DIR)/arch/arm/dts/Makefile\n' >> "$UB_MK"
# D. 物理同步配置模板并封锁交互
printf '\tcp $(PKG_BUILD_DIR)/configs/mt7981_emmc_rfb_defconfig $(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf '\tsed -i "s/DEFAULT_DEVICE_TREE=.*/DEFAULT_DEVICE_TREE=\\"mt7981-sl3000-emmc\\"/" $(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf '\techo "CONFIG_TEXT_BASE=0x41e00000" >> $(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"

printf 'define Build/Compile\n\t$(MAKE) -C $(PKG_BUILD_DIR) mt7981_sl3000_emmc_defconfig\n\t$(MAKE) -C $(PKG_BUILD_DIR) olddefconfig\n\t$(MAKE) -C $(PKG_BUILD_DIR) CROSS_COMPILE=$(TARGET_CROSS) DEVICE_DTS=mt7981-sl3000-emmc\nendef\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc/install\n\t$(INSTALL_DIR) $(1)\n\t$(CP) $(PKG_BUILD_DIR)/u-boot.bin $(1)/u-boot-sl3000.bin\nendef\n' >> "$UB_MK"
printf '$(eval $(call BuildPackage,uboot-mediatek-mt7981-sl3000-emmc))\n' >> "$UB_MK"

# 5. [配置锁定]
rm -f .config
cat <<EOF > .config
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y
CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
EOF
