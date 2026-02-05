#!/bin/bash
set -e

# 定位路径 (基于你的仓库结构)
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000 Final Audit] 正在执行 25.12 基因锁定与物理缝合..."

# 1. 注入镜像生成规则 (三件套之一: filogic.mk 在根目录)
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 2. 【核心修复】物理缝合 DTS，彻底解决 #include 找不到的问题
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
        echo "🔗 正在物理缝合底层定义: $ORIGIN_DTSI"
        # 提取 dtsi 内容，剔除重复的头部声明，作为底座
        sed -E '/\/dts-v1\/|#include/d' "$ORIGIN_DTSI"
    fi

    echo -e "\n/* --- SL3000 CUSTOM SECTION --- */\n"
    
    # 注入你的 DTS (三件套之二: mt7981b-sl3000-emmc.dts 在根目录)
    # 物理删除报错的 include 行，并自动将内存修正为 1GB (0x40000000)
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g' | tr -d '\r'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 3. 工具链硬链接劫持 (解决 m4sugar.m4 错误)
mkdir -p "${WORKDIR}/staging_dir/host/bin"
mkdir -p "${WORKDIR}/staging_dir/host/stamp"
for tool in m4 flex bison lex; do
    rm -f "${WORKDIR}/staging_dir/host/bin/$tool"
    ln -sf "/usr/bin/$tool" "${WORKDIR}/staging_dir/host/bin/$tool"
    touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done
touch "${WORKDIR}/staging_dir/host/.tools_install_y"

# 4. 同步 Feeds 并注入配置 (三件套之三: sl3000_defconfig 在根目录)
cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config

# 强制注入分区锁定
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
echo "CONFIG_TARGET_KERNEL_PARTSIZE=128" >> .config
echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024" >> .config

make defconfig
echo "✅ [Final Audit] 补丁注入完成。"
