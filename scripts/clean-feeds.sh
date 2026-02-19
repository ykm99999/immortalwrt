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

# 3. 🔥 [硬核物理重写] 彻底解决 U-Boot 逻辑冲突
cat <<EOF > package/boot/uboot-mediatek/Makefile
include \$(TOPDIR)/rules.mk
include \$(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-mediatek
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk

define Package/uboot-mediatek-mt7981-sl3000-emmc
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for SL3000 (MT7981) eMMC
  DEPENDS:=@TARGET_mediatek
endef

define Build/Compile
	# 物理强制指定构建命令，避开原版循环
	\$(MAKE) -C \$(PKG_BUILD_DIR) mt7981_sl3000_emmc_defconfig
	\$(MAKE) -C \$(PKG_BUILD_DIR) DEVICE_DTS=mt7981-sl3000-emmc
endef

define Package/uboot-mediatek-mt7981-sl3000-emmc/install
	\$(INSTALL_DIR) \$(1)
	\$(CP) \$(PKG_BUILD_DIR)/u-boot.bin \$(1)/
endef

\$(eval \$(call BuildPackage,uboot-mediatek-mt7981-sl3000-emmc))
EOF

# 4. 🔥 [硬核物理重写] 彻底解决 ATF (ARM Trusted Firmware) 逻辑冲突
cat <<EOF > package/boot/atf-mediatek/Makefile
include \$(TOPDIR)/rules.mk

PKG_NAME:=atf-mediatek
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk

define Package/atf-mediatek-mt7981-sl3000-emmc
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=ATF for SL3000 (MT7981) eMMC
  DEPENDS:=@TARGET_mediatek
endef

define Build/Compile
	# 物理锁定编译参数
	\$(MAKE) -C \$(PKG_BUILD_DIR) PLAT=mt7981 all
endef

\$(eval \$(call BuildPackage,atf-mediatek-mt7981-sl3000-emmc))
EOF

# 5. [物理修复] 冲突铲平 (承袭原文)
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils

# 6. [结构死锁] .config 物理配置
rm -f .config
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_atf-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_luci=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-theme-bootstrap=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-i18n-base-zh-cn=y\n' >> .config

# 7. [路径物理对齐] DTS 注入
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="\$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "\$DTS_PATH"
    [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ] && cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "\$DTS_PATH/"
done

# 8. [旗舰打包补丁] 重构 filogic.mk (物理死锁)
MK_TARGET="target/linux/mediatek/image/filogic.mk"
printf 'define Device/3000-emmc\n' > filogic.mk.final
printf '  DEVICE_VENDOR := SL\n' >> filogic.mk.final
printf '  DEVICE_MODEL := 3000-eMMC\n' >> filogic.mk.final
printf '  DEVICE_DTS := mt7981b-3000-emmc\n' >> filogic.mk.final
printf '  DEVICE_DTS_DIR := \$(DTS_DIR)/mediatek\n' >> filogic.mk.final
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
cp -fv "filogic.mk.final" "\$MK_TARGET"
