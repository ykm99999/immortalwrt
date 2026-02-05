#!/bin/bash
set -e
REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 执行全集成修复..."

# 1. 物理注入 (延续之前的成功逻辑)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. DTS 缝合 (延续 1GB 内存与 include 修复)
mkdir -p "${WORKDIR}/custom_files"
ORIGIN_DTSI=$(find "${WORKDIR}/target/linux/mediatek/" -name "mt7981.dtsi" | head -n 1)
{ 
    echo '/dts-v1/;'
    echo '#include <dt-bindings/interrupt-controller/arm-gic.h>'
    echo '#include <dt-bindings/clock/mt7981-clk.h>'
    echo '#include <dt-bindings/gpio/gpio.h>'
    echo '#include <dt-bindings/leds/common.h>'
    echo '#include <dt-bindings/input/input.h>'
    [ -f "$ORIGIN_DTSI" ] && sed -E '/\/dts-v1\/|#include/d' "$ORIGIN_DTSI"
    echo -e "\n/* --- SL3000 1GB FLAGSHIP --- */\n"
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 3. 环境劫持 (延续 Prereq 修复)
mkdir -p "${WORKDIR}/staging_dir/host/bin" "${WORKDIR}/staging_dir/host/stamp"
for tool in m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    [ -n "$SYS_PATH" ] && ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool" && touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done

# 4. Feeds 处理 (延续 PHP 递归冲突修复)
cd "${WORKDIR}"
./scripts/feeds update -a
rm -rf feeds/packages/lang/php8 feeds/packages/admin/zabbix
./scripts/feeds install -a

# 5. 配置对齐 (强制锁定设备)
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_CCACHE=y"
} >> .config

yes "" | make oldconfig
make defconfig
