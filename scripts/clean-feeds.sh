#!/bin/bash
set -e

echo ">>> [SL3000 Final-V7] 正在执行环境劫持与初次注入..."

ROOT_DIR=$(pwd)
SRC_DIR="${GITHUB_WORKSPACE}/custom-repo"

# 1. 环境劫持 (加速编译)
mkdir -p staging_dir/host/bin staging_dir/host/stamp
for tool in m4 flex bison; do
    ln -snf /usr/bin/$tool staging_dir/host/bin/$tool
done
touch staging_dir/host/.tools_install_y staging_dir/host/stamp/.tools_compile_y

# 2. 定位资源
DTS_SRC=$(find "$SRC_DIR" -type f -name "*sl3000*.dts" | head -n 1)
MK_SRC=$(find "$SRC_DIR" -type f -name "filogic.mk" | head -n 1)

# 3. 初次注入目标路径 (为内核 prepare 做准备)
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

# 拷贝原始 DTS (暂时不做处理)
[ -f "$DTS_SRC" ] && cp -f "$DTS_SRC" "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
# 拷贝 Makefile 定义
[ -f "$MK_SRC" ] && cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# 4. Feeds 与配置锁定
./scripts/feeds update -a && ./scripts/feeds install -a
cat <<EOT > .config
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOT
make defconfig
