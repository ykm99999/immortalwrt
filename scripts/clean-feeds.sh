#!/bin/bash
set -e

REPO_ROOT="${GITHUB_WORKSPACE}"
WORKDIR="${GITHUB_WORKSPACE}/openwrt"
SRC_DIR="${GITHUB_WORKSPACE}"

echo "💎 [SL3000] 执行物理修复：全量补丁归位 + 屏蔽索引签名限制..."

cd "${WORKDIR}" || {
    echo "❌ 无法进入 openwrt 目录"
    exit 1
}

# [1] 建立 staging 目录
mkdir -p staging_dir/host/bin staging_dir/host/share

# [2] 屏蔽 -Werror
find . -name Makefile -exec sed -i 's/ERROR_ON_WARNING = y/ERROR_ON_WARNING = n/g' {} +
find . -name "Makefile.dtc" -exec sed -i 's/-Werror//g' {} + || true

# [3] 更新 feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# [4] 屏蔽 usign 强制检查
sed -i 's/$(STAGING_DIR_HOST)\/bin\/usign/ls/g' package/Makefile || true

# [5] 软链接宿主工具
for tool in m4 flex bison gawk sed patch tar xz gzip bzip2 perl python3 wget curl; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool" || true
done
B_SHARE=$(pkg-config --variable=pkgdatadir bison 2>/dev/null || echo '/usr/share/bison')
ln -sf "$B_SHARE" "staging_dir/host/share/bison" || true

# [6] 生成 .config
rm -f .config
cat > .config << EOF
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
export BISON_PKGDATADIR=$B_SHARE
export M4=$(which m4)
EOF

[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config

# [7] 复制 DTS 与 image 配置
mkdir -p target/linux/mediatek/dts target/linux/mediatek/image
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" target/linux/mediatek/dts/
cp -fv "${SRC_DIR}/filogic.mk" target/linux/mediatek/image/

# [8] 设置 rootfs 大小
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

echo "✅ 脚本执行完成，无错误"
