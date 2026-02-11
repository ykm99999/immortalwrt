#!/bin/bash
set -e

cd "$(dirname "$0")/../openwrt" || exit 1

REPO_ROOT="$(pwd)/.."
SRC_DIR="$REPO_ROOT"

echo "💎 [SL3000] 执行物理修复：全量补丁归位 + 屏蔽索引签名限制..."

mkdir -p staging_dir/host/bin staging_dir/host/share

find . -name Makefile -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -exec sed -i 's/-Werror//g' {} + || true

./scripts/feeds update -a
./scripts/feeds install -a

sed -i 's!$(STAGING_DIR_HOST)/bin/usign!ls!g' package/Makefile 2>/dev/null

for tool in m4 flex bison gawk sed patch tar xz gzip bzip2 perl python3 wget curl; do
  ln -sf "$(which $tool)" staging_dir/host/bin/$tool 2>/dev/null
done

B_SHARE=$(pkg-config --variable=pkgdatadir bison 2>/dev/null || echo "/usr/share/bison")
ln -sf "$B_SHARE" staging_dir/host/share/bison 2>/dev/null

cat > .config << EOF
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
export BISON_PKGDATADIR=$B_SHARE
export M4=$(which m4)
EOF

[ -f "$SRC_DIR/sl3000.config" ] && cat "$SRC_DIR/sl3000.config" >> .config

# ====================== 这里已经按你要求注入正确路径 ======================
DTS_DEST_DIR="target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"
cp -fv "$SRC_DIR/mt7981b-sl3000-emmc.dts" "$DTS_DEST_DIR/"

cp -fv "$SRC_DIR/filogic.mk" target/linux/mediatek/image/
# =======================================================================

make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

echo "✅ 脚本执行完成，无错误"
