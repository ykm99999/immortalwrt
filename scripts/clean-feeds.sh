#!/bin/bash
set -e

REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000 Flagship] 执行物理缝合补丁..."

# 1. 验证三件套
for f in mt7981b-sl3000-emmc.dts filogic.mk sl3000_defconfig; do
    [ -f "${REPO_ROOT}/$f" ] || { echo "❌ 缺失组件: $f"; exit 1; }
done

# 2. 注入镜像规则
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 3. 构造专属源码 (物理缝合)
mkdir -p "${WORKDIR}/custom_files"
ORIGIN_DTSI=$(find "${WORKDIR}/target/linux/mediatek/" -name "mt7981.dtsi" | head -n 1)

{ 
    echo '/dts-v1/;'
    echo '#include <dt-bindings/interrupt-controller/arm-gic.h>'
    echo '#include <dt-bindings/clock/mt7981-clk.h>'
    echo '#include <dt-bindings/clock/mt7981-clk.h>' # 冗余保护
    echo '#include <dt-bindings/gpio/gpio.h>'
    echo '#include <dt-bindings/leds/common.h>'
    echo '#include <dt-bindings/input/input.h>'
    
    if [ -f "$ORIGIN_DTSI" ]; then
        sed -E '/\/dts-v1\/|#include/d' "$ORIGIN_DTSI"
    fi

    echo -e "\n/* --- SL3000 FLAGSHIP CUSTOM --- */\n"
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 4. 宿主机工具链劫持
mkdir -p "${WORKDIR}/staging_dir/host/bin" "${WORKDIR}/staging_dir/host/stamp"
for tool in m4 flex bison lex; do
    ln -sf "/usr/bin/$tool" "${WORKDIR}/staging_dir/host/bin/$tool"
    touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done
touch "${WORKDIR}/staging_dir/host/.tools_install_y"

# 5. Feeds & Config
cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=128" >> .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config

make defconfig
echo "✅ 旗舰补丁就绪。"
