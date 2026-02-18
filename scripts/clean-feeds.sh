#!/bin/bash
set -eo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

cd "${WORKDIR}"

# 1. 🔥 [物理核爆] 彻底摧毁已生成的 feeds 索引和配置文件
# 只有彻底删掉这些，sed 修改后的源才会生效，否则系统会读取旧的配置
rm -rf feeds.conf
rm -rf feeds/

# 2. 🔥 [源头封锁] 物理重写 feeds.conf.default
# 不再用 sed 修改，直接物理重写，只保留基础白名单，剔除 telephony/video/routing/management
printf 'src-git packages https://github.com/immortalwrt/packages.git\n' > feeds.conf.default
printf 'src-git luci https://github.com/immortalwrt/luci.git\n' >> feeds.conf.default
printf 'src-git base https://github.com/immortalwrt/openwrt/tree/openwrt-21.02/package/base\n' >> feeds.conf.default

# 3. 物理执行更新
./scripts/feeds update -a

# 4. 🔥 [物理绝育] 在安装前，物理铲平 luci 仓库下的冗余协议和模块
# 这样即使 install -a 执行，也会因为找不到目录而跳过，彻底解决日志中的 luci-mod-dsl 问题
rm -rf feeds/luci/modules/luci-mod-dsl
rm -rf feeds/luci/protocols/luci-proto-3g
rm -rf feeds/luci/protocols/luci-proto-yggdrasil
rm -rf feeds/luci/protocols/luci-proto-batman-adv
rm -rf feeds/luci/applications/luci-app-*

# 5. 专属物理安装
./scripts/feeds install -a

# 6. [物理修复] 冲突铲平 (承袭原文)
rm -rf package/boot/arm-trusted-firmware-microchipsw
rm -rf package/utils/audit
rm -rf package/emortal/autosamba
rm -rf package/utils/policycoreutils

# 7. 🔥 [结构死锁] 企业旗舰级 .config 物理配置
rm -f .config
printf 'CONFIG_TARGET_mediatek=y\n' > .config
printf 'CONFIG_TARGET_mediatek_filogic=y\n' >> .config
printf 'CONFIG_TARGET_mediatek_filogic_DEVICE_3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_uboot-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_atf-mediatek-mt7981-sl3000-emmc=y\n' >> .config
printf 'CONFIG_PACKAGE_luci=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-theme-bootstrap=y\n' >> .config
printf 'CONFIG_PACKAGE_luci-i18n-base-zh-cn=y\n' >> .config

# 8. [路径物理对齐] DTS 物理注入 (针对 files-6.12)
find target/linux/mediatek/ -name "files-*" -type d | while read -r dir; do
    DTS_PATH="$dir/arch/arm64/boot/dts/mediatek"
    mkdir -p "$DTS_PATH"
    if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/"
        cp -v "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_PATH/mt7981-rfb.dts"
    fi
done

# 9. [旗舰打包补丁] filogic.mk 物理注入
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
