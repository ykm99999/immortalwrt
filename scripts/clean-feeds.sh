#!/bin/bash
set -eo pipefail

# 物理定位：REPO_ROOT 为 GitHub Workspace 根目录，WORKDIR 为 openwrt 目录
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
[ ! -f "dl/u-boot-2024.10.tar.bz2" ] && wget -t 3 -T 30 -O dl/u-boot-2024.10.tar.bz2 https://ftp.denx.de/pub/u-boot/u-boot-2024.10.tar.bz2

# 3. [环境刷新]
rm -rf feeds/
./scripts/feeds update -a
./scripts/feeds install -a -f

# 4. 🔥 [物理外科手术：从根目录物理覆盖 filogic.mk]
MK_DIR="target/linux/mediatek/image"
MK_FILE="${MK_DIR}/filogic.mk"
mkdir -p "$MK_DIR"

if [ -f "${SRC_DIR}/filogic.mk" ]; then
    printf "正在从根目录物理提取 filogic.mk...\n"
    cp -f "${SRC_DIR}/filogic.mk" "$MK_FILE"
    chmod 644 "$MK_FILE"
else
    printf "错误：根目录未找到 filogic.mk，物理自愈生成...\n"
    cat > "$MK_FILE" <<EOF
define Device/mt7981-sl3000-emmc
  DEVICE_VENDOR := SL3000
  DEVICE_MODEL := eMMC-Router
  DEVICE_DTS := mt7981b-3000-emmc
  SUPPORTED_DEVICES := mt7981-sl3000-emmc
endef
\$(eval \$(call BuildImage,mt7981-sl3000-emmc))
EOF
fi

# 5. 🔥 [U-Boot 2024.10 物理注入 - 保持原文逻辑]
UB_MK="package/boot/uboot-mediatek/Makefile"
rm -rf package/boot/uboot-mediatek/patches
mkdir -p package/boot/uboot-mediatek

cat > "$UB_MK" <<EOF
include \$(TOPDIR)/rules.mk
include \$(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uboot-mediatek
PKG_VERSION:=2024.10
PKG_RELEASE:=1

PKG_SOURCE:=u-boot-\$(PKG_VERSION).tar.bz2
PKG_HASH:=f7869ef42674681617260f8f1723467f9345095e26915152865d18d4076e03f0
PKG_BUILD_DIR:=\$(BUILD_DIR)/u-boot-\$(PKG_VERSION)

include \$(INCLUDE_DIR)/package.mk

define Package/uboot-mediatek-mt7981-sl3000-emmc
  SECTION:=boot
  CATEGORY:=Boot Loaders
  TITLE:=U-Boot for SL3000
  DEPENDS:=@TARGET_mediatek
endef

define Build/Prepare
	\$(Build/Prepare/Default)
	echo "#define CFG_SYS_INIT_RAM_ADDR 0x40000000" >> \$(PKG_BUILD_DIR)/include/configs/mt7981.h
	echo "#define CFG_SYS_INIT_RAM_SIZE 0x00040000" >> \$(PKG_BUILD_DIR)/include/configs/mt7981.h
	echo "#define CFG_SYS_INIT_SP_ADDR (CFG_SYS_INIT_RAM_ADDR + CFG_SYS_INIT_RAM_SIZE - 0x10)" >> \$(PKG_BUILD_DIR)/include/configs/mt7981.h
	cp \$(PKG_BUILD_DIR)/arch/arm/dts/mt7981-emmc-rfb.dts \$(PKG_BUILD_DIR)/arch/arm/dts/mt7981-sl3000-emmc.dts
	sed -i "s/mt7981-rfb.dtb/mt7981-rfb.dtb mt7981-sl3000-emmc.dtb/" \$(PKG_BUILD_DIR)/arch/arm/dts/Makefile
	cp \$(PKG_BUILD_DIR)/configs/mt7981_emmc_rfb_defconfig \$(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig
	sed -i 's/DEFAULT_DEVICE_TREE=.*/DEFAULT_DEVICE_TREE="mt7981-sl3000-emmc"/' \$(PKG_BUILD_DIR)/configs/mt7981_sl3000_emmc_defconfig
endef

define Build/Compile
	\$(MAKE) -C \$(PKG_BUILD_DIR) mt7981_sl3000_emmc_defconfig
	\$(MAKE) -C \$(PKG_BUILD_DIR) olddefconfig
	\$(MAKE) -C \$(PKG_BUILD_DIR) CROSS_COMPILE=\$(TARGET_CROSS) DEVICE_DTS=mt7981-sl3000-emmc
endef

define Package/uboot-mediatek-mt7981-sl3000-emmc/install
	\$(INSTALL_DIR) \$(1)
	\$(CP) \$(PKG_BUILD_DIR)/u-boot.bin \$(1)/u-boot-sl3000.bin
endef

\$(eval \$(call BuildPackage,uboot-mediatek-mt7981-sl3000-emmc))
EOF

# 6. [内核 DTS 物理注入 - 目标根目录文件]
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
    fi
done

# 7. [物理配置应用 - 从根目录 sl3000.config 提取]
if [ -f "${SRC_DIR}/sl3000.config" ]; then
    printf "正在应用根目录物理配置文件...\n"
    cp -f "${SRC_DIR}/sl3000.config" .config
    # 物理锁定关键分区数值
    sed -i 's/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=131072/' .config
    sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1048576/' .config
else
    printf "警告：未找到 sl3000.config，执行物理保底配置...\n"
    printf 'CONFIG_TARGET_mediatek=y\nCONFIG_TARGET_mediatek_filogic=y\nCONFIG_TARGET_mediatek_filogic_DEVICE_mt7981-sl3000-emmc=y\n' > .config
    printf 'CONFIG_TARGET_KERNEL_PARTSIZE=131072\nCONFIG_TARGET_ROOTFS_PARTSIZE=1048576\n' >> .config
fi
