#!/bin/bash
set -e

echo ">>> [SL3000 Ultimate-Fix] 启动物理缝合与环境劫持..."

ROOT_DIR=$(pwd)
[ -z "$GITHUB_WORKSPACE" ] && GITHUB_WORKSPACE=$(cd ..; pwd)
SRC_DIR=$(find "$GITHUB_WORKSPACE" -maxdepth 2 -type d -name "*custom-repo*" | head -n 1)

# 1. 环境工具劫持 (延续成功基因，跳过工具编译)
mkdir -p staging_dir/host/bin staging_dir/host/stamp
for tool in m4 flex bison; do
    ln -snf /usr/bin/$tool staging_dir/host/bin/$tool
done
ln -snf /usr/bin/flex staging_dir/host/bin/lex
touch staging_dir/host/.tools_install_y staging_dir/host/stamp/.tools_compile_y staging_dir/host/stamp/.m4_installed

# 2. DTS 物理缝合 (彻底解决 No such file 报错)
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

# 找到系统原始的 dtsi
ORIGIN_DTSI=$(find target/linux/mediatek/ -name "mt7981.dtsi" | head -n 1)
DTS_SRC=$(find "$SRC_DIR" -type f -name "*sl3000*.dts" | head -n 1)

echo "🛠️ 正在将 dtsi 内容物理注入 dts..."
{
    echo '/dts-v1/;'
    echo '#include <dt-bindings/leds/common.h>'
    echo '#include <dt-bindings/input/input.h>'
    # 注入原始 dtsi 内容（去掉开头的版本声明和包含行）
    sed -E '/\/dts-v1\/;|#include/d' "$ORIGIN_DTSI"
    echo -e "\n/* --- SL3000 1GB SECTION --- */\n"
    # 注入你的自定义内容（去掉包含 mt7981.dtsi 的那行）
    tr -d '\r' < "$DTS_SRC" | sed -E '/\/dts-v1\/;|#include/d'
} > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 3. 注入 1GB 扩容配置与设备 Makefile
./scripts/feeds update -a && ./scripts/feeds install -a
touch .config
cat <<EOT > .config
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOT

MK_SRC=$(find "$SRC_DIR" -type f -name "filogic.mk" | head -n 1)
[ -f "$MK_SRC" ] && cp -fv "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

make defconfig
