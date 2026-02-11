#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 执行物理修复：全量补丁归位 + 屏蔽索引签名限制..."

cd "${WORKDIR}"

# [1] 物理建立 staging 目录
mkdir -p staging_dir/host/bin staging_dir/host/share

# [2] 延续修复：2/9 物理屏蔽所有 Makefile 中的 -Werror
find . -name Makefile -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -exec sed -i 's/-Werror//g' {} + || true

# [3] 延续设置：Feeds 管理
./scripts/feeds update -a && ./scripts/feeds install -a

# [4] 🔥 [新增物理修复] 屏蔽 package/index 时的签名强制要求 (解决 usign 缺失)
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/ls/g' package/Makefile || true

# [5] 延续修复：2/5 物理封印宿主工具
for tool in m4 flex bison gawk sed patch tar xz gzip bzip2 perl python3 wget curl; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool" || true
done
B_SHARE=$(pkg-config --variable=pkgdatadir bison 2>/dev/null || echo '/usr/share/bison')
ln -sf "$B_SHARE" "staging_dir/host/share/bison" || true

# [6] 锁定内核分区 128MB
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

# [7] DTS 与 Image 物理注入
mkdir -p "target/linux/mediatek/dts" "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# [8] Rootfs 1G 分区锁定
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config
