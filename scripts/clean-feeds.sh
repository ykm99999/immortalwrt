#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 🔥 [彻底解决 apk 报错] 移除外部 base 源，强制使用源码内置的 stable 核心规则
rm -rf feeds.conf
printf 'src-git packages https://github.com/immortalwrt/packages.git\n' > feeds.conf.default
printf 'src-git luci https://github.com/immortalwrt/luci.git\n' >> feeds.conf.default

# 2. [物理清场]
rm -rf feeds/

# 3. 物理执行更新
./scripts/feeds update -a

# 4. 🔥 [彻底解决目标漂移] 物理粉碎所有非 MT7981 的 U-Boot 逻辑定义
# 强制删除 Makefile 中关于 mt7620, mt7621, mt7622 等旧型号的定义，编译器将“无路可走”
if [ -f "package/boot/uboot-mediatek/Makefile" ]; then
    sed -i '/define Device\/mt7620/,/endef/d' package/boot/uboot-mediatek/Makefile
    sed -i '/define Device\/mt7621/,/endef/d' package/boot/uboot-mediatek/Makefile
    sed -i '/define Device\/mt7622/,/endef/d' package/boot/uboot-mediatek/Makefile
    sed -i '/define Device\/mt7623/,/endef/d' package/boot/uboot-mediatek/Makefile
    sed -i '/define Device\/mt7628/,/endef/d' package/boot/uboot-mediatek/Makefile
    sed -i '/define Device\/mt7629/,/endef/d' package/boot/uboot-mediatek/Makefile
fi

# 5. [物理精准手术] 移除 LuCI 冗余
find feeds/luci/protocols/ -mindepth 1 ! -name "*static*" ! -name "*dhcp*" ! -name "*ppp*" -exec rm -rf {} +
rm -rf feeds/luci/applications/luci-app-*
rm -rf feeds/luci/modules/luci-mod-dsl

# 6. [物理授权] 执行强制覆盖安装
./scripts/feeds install -a -f

# 7. [物理修复] 冲突铲平 (承袭原文)
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils

# 8. 🔥 [结构死锁] .config 物理配置 (硬性屏蔽位)
rm -f .config
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_atf-mediatek-mt7981-sl3000-emmc=y\n' >> .config
# 物理封杀旧型号选择逻辑
printf '# CONFIG_PACKAGE_uboot-mediatek-mt7620 is not set\n' >> .config
printf '# CONFIG_PACKAGE_uboot-mediatek-mt7621 is not set\n' >> .config
printf 'CONFIG_PACKAGE_luci=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-theme-bootstrap=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-i18n-base-zh-cn=y\n' >> .config

# 9. [路径物理对齐] DTS 注入
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981-rfb.dts"
    fi
done

# 10. [旗舰打包补丁] 重构 filogic.mk
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
