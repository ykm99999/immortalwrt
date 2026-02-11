#!/bin/bash
set -e

REPO_ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 严格对齐仓库路径：全量物理修复"

cd "${WORKDIR}"

# 1.  staging 目录
mkdir -p staging_dir/host/bin staging_dir/host/share

# 2. 关闭 -Werror
find . -name Makefile -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -exec sed -i 's/-Werror//g' {} + || true

# 3. feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# 4. 屏蔽 usign 签名
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/ls/g' package/Makefile || true

# 5. 宿主工具软链接
for tool in m4 flex bison gawk sed patch tar xz gzip bzip2 perl python3 wget curl; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool" || true
done
B_SHARE=$(pkg-config --variable=pkgdatadir bison 2>/dev/null || echo '/usr/share/bison')
ln -sf "$B_SHARE" "staging_dir/host/share/bison" || true

# 6. 【严格对你仓库路径】读取根目录 sl3000.config
rm -f .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "export BISON_PKGDATADIR=$B_SHARE"
    echo "export M4=$(which m4)"
} > .config
[ -f "${REPO_ROOT}/sl3000.config" ] && cat "${REPO_ROOT}/sl3000.config" >> .config

# 7. 【严格对你仓库路径】拷贝根目录 DTS + filogic.mk
cp -fv "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"
cp -fv "${REPO_ROOT}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 8. rootfs 1G
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config
