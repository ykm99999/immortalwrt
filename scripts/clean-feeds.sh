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

# 3. [物理源码注入]
mkdir -p dl
curl -L --connect-timeout 20 --retry 5 "https://github.com/u-boot/u-boot/archive/refs/tags/v2024.10.tar.gz" -o "dl/u-boot-2024.10.tar.gz"

# 4. 🔥 [物理修复：深度封锁 U-Boot 交互黑洞]
UB_MK="package/boot/uboot-mediatek/Makefile"
rm -rf package/boot/uboot-mediatek/patches
mkdir -p package/boot/uboot-mediatek

printf 'include $(TOPDIR)/rules.mk\ninclude $(INCLUDE_DIR)/kernel.mk\n' > "$UB_MK"
printf 'PKG_NAME:=uboot-mediatek\nPKG_VERSION:=2024.10\nPKG_RELEASE:=1\n' >> "$UB_MK"
printf 'PKG_SOURCE:=u-boot-$(PKG_VERSION).tar.gz\n' >> "$UB_MK"
printf 'PKG_BUILD_DIR:=$(BUILD_DIR)/u-boot-$(PKG_VERSION)\n' >> "$UB_MK"
printf 'include $(INCLUDE_DIR)/package.mk\n' >> "$UB_MK"
printf 'define Package/uboot-mediatek-mt7981-sl3000-emmc\n  SECTION:=boot\n  CATEGORY:=Boot Loaders\n  TITLE:=U-Boot for SL3000 (MT7981) eMMC\n  DEPENDS:=@TARGET_mediatek\nendef\n' >> "$UB_MK"
printf 'define Build/Prepare\n\t$(Build/Prepare/Default)\n' >> "$UB_MK"
printf '\tmkdir -p $(PKG_BUILD_DIR)/configs\n' >> "$UB_MK"
# 物理补全所有核心物理地址，彻底消灭 NEW 符号
printf '\tprintf "CONFIG_ARM=y\\nCONFIG_ARCH_MEDIATEK=y\\nCONFIG_TARGET_MT7981=y\\nCONFIG_SYS_TEXT_BASE=0x41e00000\\nCONFIG_TEXT_BASE=0x41e00000\\nCONFIG_SYS_LOAD_ADDR=0x40000000\\nCONFIG_SYS_UBOOT_START=0x41e00000\\nCONFIG_MTK_BROM_HEADER_INFO=\\"media=emmc\\"\\nCONFIG_DEFAULT_DEVICE_TREE=\\"mt7981-sl3000-emmc\\"\\n" > $(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig\n' >> "$UB_MK"
printf 'endef\n' >> "$UB_MK"
# 物理强制：执行 olddefconfig 自动选择默认值，物理断绝 Stdin 输入路径
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

# 6. [DTS 物理注入]
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
done
