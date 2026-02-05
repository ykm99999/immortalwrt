#!/bin/bash
set -e

# 定位路径
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000 V4] 执行物理缝合补丁..."

# 1. 注入镜像规则 (三件套: filogic.mk 在根目录)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. 构造无依赖 DTS (物理缝合 mt7981.dtsi)
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

    echo -e "\n/* --- SL3000 CUSTOM SECTION --- */\n"
    
    # 从根目录读取 dts
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g' | tr -d '\r'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 3. 工具链硬链接
mkdir -p "${WORKDIR}/staging_dir/host/bin"
mkdir -p "${WORKDIR}/staging_dir/host/stamp"
for tool in m4 flex bison lex; do
    rm -f "${WORKDIR}/staging_dir/host/bin/$tool"
    ln -sf "/usr/bin/$tool" "${WORKDIR}/staging_dir/host/bin/$tool"
    touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done
touch "${WORKDIR}/staging_dir/host/.tools_install_y"

# 4. Feeds & Config (defconfig 在根目录)
cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config

# 强制注入分区大小
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=128" >> .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config

make defconfig
