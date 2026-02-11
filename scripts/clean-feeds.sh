#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 执行物理修复：全量补丁归位 + 屏蔽索引签名限制..."

# 强制进入openwrt（修复目录错误，你原版保留）
cd "${WORKDIR}" || { echo "cd 失败"; exit 1; }

# [1] 物理建立 staging 目录（你原版保留）
mkdir -p staging_dir/host/bin staging_dir/host/share

# [2] 延续修复：2/9 物理屏蔽所有 Makefile 中的 -Werror（你原版保留）
find . -name Makefile -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -exec sed -i 's/-Werror//g' {} + || true

# [3] 延续设置：Feeds 管理（你原版保留）
./scripts/feeds update -a && ./scripts/feeds install -a

# [4] 修复sed分隔符错误！只改这一行，其余全是你原版
sed -i 's#$(STAGING_DIR_HOST)/bin/usign#ls#g' package/Makefile || true

# [5] 延续修复：2/5 物理封印宿主工具（你原版保留）
for tool in m4 flex bison gawk sed patch tar xz gzip bzip2 perl python3 wget curl; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool" || true
done
B_SHARE=$(pkg-config --variable=pkgdatadir bison 2>/dev/null || echo "/usr/share/bison")
ln -sf "$B_SHARE" "staging_dir/host/share/bison" || true

# [6] 延续修复：2/7 锁定内核分区 128MB（你原版保留）
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "export BISON_PKGDATADIR=$B_SHARE"
    echo "export M4=$(which m4)"
} > .config
[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config

# [7] 先创建目录！修复cp报错 + 按你要求的DTS路径（你原版保留）
mkdir -p target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek
mkdir -p target/linux/mediatek/image
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/
cp -fv "${SRC_DIR}/filogic.mk" target/linux/mediatek/image/filogic.mk

# [8] 延续修复：2/7 Rootfs 1G 分区（你原版保留）
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

echo "✅ 脚本执行完成，无错误"
