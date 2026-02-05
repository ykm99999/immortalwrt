#!/bin/bash
set -e

REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 正在执行全量环境劫持..."

# 1. 注入三件套
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. 物理缝合 DTS (带内存锁死逻辑)
mkdir -p "${WORKDIR}/custom_files"
ORIGIN_DTSI=$(find "${WORKDIR}/target/linux/mediatek/" -name "mt7981.dtsi" | head -n 1)

{ 
    echo '/dts-v1/;'
    echo '#include <dt-bindings/interrupt-controller/arm-gic.h>'
    echo '#include <dt-bindings/clock/mt7981-clk.h>'
    echo '#include <dt-bindings/gpio/gpio.h>'
    echo '#include <dt-bindings/leds/common.h>'
    echo '#include <dt-bindings/input/input.h>'
    if [ -f "$ORIGIN_DTSI" ]; then
        sed -E '/\/dts-v1\/|#include/d' "$ORIGIN_DTSI"
    fi
    echo -e "\n/* --- SL3000 FLAGSHIP 1GB --- */\n"
    # 强制物理覆盖内存定义并删除 include 依赖
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 3. 【绝对暴力】劫持所有可能的 prereq 命令
mkdir -p "${WORKDIR}/staging_dir/host/bin"
mkdir -p "${WORKDIR}/staging_dir/host/stamp"

# 补充了 python 和实路径工具
TOOLS="m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3"
for tool in $TOOLS; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    if [ -n "$SYS_PATH" ]; then
        ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool"
        touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
    fi
done

# 特殊处理：强制 getopt 软链接
ln -sf /usr/bin/getopt "${WORKDIR}/staging_dir/host/bin/getopt"

# 4. Feeds & Config
cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config

# 强行注入旗舰分区与 CCACHE 
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d; /CONFIG_CCACHE/d' .config
{
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_CCACHE=y"
} >> .config

make defconfig
echo "✅ 暴力破解环境已就绪。"
