#!/bin/bash
set -eo pipefail

# 🎯 物理定位：脚本在 scripts/ 下，仓库根目录是 ..
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo -e "\033[32m🚀 [SL3000] 执行 25.12 物理回退：恢复 136MB GPT 对齐模式 ...\033[0m"

cd "${WORKDIR}"

# 1. 物理环境准备 (原文照抄)
mkdir -p staging_dir/host
touch staging_dir/host/.prereq-build

# 2. 🔥 [.config] 严格对齐核心配置 (恢复 128MB 内核分区声明)
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
    echo "CONFIG_TARGET_IMAGES_GZIP=y"
    echo "CONFIG_PACKAGE_kmod-mmc=y"
    echo "CONFIG_PACKAGE_kmod-sdhci-mtk=y"
    echo "CONFIG_PACKAGE_kmod-fs-f2fs=y"
    echo "CONFIG_PACKAGE_f2fs-tools=y"
    echo "CONFIG_PACKAGE_f2fsck=y"
    echo "CONFIG_PACKAGE_parted=y"
    echo "CONFIG_PACKAGE_lsblk=y"
    echo "CONFIG_PACKAGE_blkid=y"
    echo "CONFIG_PACKAGE_block-mount=y"
    echo "CONFIG_PACKAGE_kmod-zram=y"
    echo "CONFIG_PACKAGE_zram-swap=y"
    echo "CONFIG_PACKAGE_luci=y"
    echo "CONFIG_PACKAGE_luci-theme-bootstrap=y"
    echo "CONFIG_PACKAGE_curl=y"
    echo "CONFIG_PACKAGE_wget-ssl=y"
    echo "CONFIG_PACKAGE_htop=y"
    echo "CONFIG_PACKAGE_nano=y"
} > .config

# 3. 🔥 [ID 修正] 物理延续：全量替换确保匹配 sl,3000-emmc
find target/linux/mediatek/ -type f \( -name "*.dts*" -o -name "*.dtsi*" \) -exec sed -i 's/sl,sl3000-emmc/sl,3000-emmc/g' {} +

# 4. 🔥 [DTS 注入] 覆盖 files-6.12 目录
DTS_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DIR"

if [ -f "${SRC_DIR}/mt7981b-3000-emmc.dts" ]; then
    cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_DIR/mt7981b-3000-emmc.dts"
    cp -fv "${SRC_DIR}/mt7981b-3000-emmc.dts" "$DTS_DIR/mt7981-rfb.dts"
else
    echo -e "\033[31m❌ 错误：仓库根目录找不到 mt7981b-3000-emmc.dts！\033[0m"
    exit 1
fi

# 5. 🔥 [MK 注入] 物理恢复填充模式
MK_TARGET="target/linux/mediatek/image/filogic.mk"
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" "$MK_TARGET"
    # 🎯 物理逻辑保护：严禁删除 pad-to 逻辑
    # 仅更新 Rootfs 逻辑尺寸，确保与 GPT 表一致
    sed -i 's/BOARD_ROOTFS_PARTSIZE := .*/BOARD_ROOTFS_PARTSIZE := 1024/g' "$MK_TARGET"
fi

# 6. 物理屏蔽签名校验 (原文照抄)
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/true/g' package/Makefile || true
sed -i 's/$(STAGING_DIR_HOST)\/bin\/ucert/true/g' package/Makefile || true

echo -e "\033[32m✅ 脚本已物理修复：136MB 填充逻辑已重新激活，准备对齐 GPT 分区表。\033[0m"
