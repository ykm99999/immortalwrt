#!/bin/bash
set -e

REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000 Factory] 解决递归依赖并加载全部修复项..."

# 1. 注入镜像规则
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. [延续修复] DTS 物理缝合与 1GB 内存锁死
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
    echo -e "\n/* --- SL3000 FLAGSHIP INTEGRATED --- */\n"
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 3. [延续修复] 暴力环境劫持 (解决 Prerequisite)
mkdir -p "${WORKDIR}/staging_dir/host/bin" "${WORKDIR}/staging_dir/host/stamp"
TOOLS="m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3"
for tool in $TOOLS; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    if [ -n "$SYS_PATH" ]; then
        ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool"
        touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
    fi
done
ln -sf /usr/bin/getopt "${WORKDIR}/staging_dir/host/bin/getopt"

# 4. [核心修复] 处理 Feeds 并强行剔除冲突组件
cd "${WORKDIR}"
./scripts/feeds update -a

# --- 外科手术：删除导致递归依赖的包目录 ---
[ -d "feeds/packages/lang/php8" ] && rm -rf "feeds/packages/lang/php8"
[ -d "feeds/packages/admin/zabbix" ] && rm -rf "feeds/packages/admin/zabbix"
# ---------------------------------------

./scripts/feeds install -a
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config

# [延续修复] 分区锁死与 CCACHE
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d; /CONFIG_CCACHE/d' .config
{
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_CCACHE=y"
} >> .config

# 强制静默生成配置，不给弹出 menuconfig 的机会
yes "" | make oldconfig
make defconfig
echo "✅ 递归依赖已清除，环境完全就绪。"
