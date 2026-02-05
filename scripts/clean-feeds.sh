#!/bin/bash
set -e

REPO_ROOT=$(pwd)
WORKDIR="${REPO_ROOT}/openwrt"

echo "🚀 [SL3000 Flagship Edition] 启动旗舰级物理缝合..."

# 1. 严格资源验证
for file in mt7981b-sl3000-emmc.dts filogic.mk sl3000_defconfig; do
    [ -f "${REPO_ROOT}/$file" ] || { echo "❌ 缺失旗舰组件: $file"; exit 1; }
done

# 2. 注入镜像规则与旗舰优化
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
cp -fv "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# 3. 构造旗舰级“自包含”DTS (1GB 内存指纹锁定)
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

    echo -e "\n/* --- SL3000 FLAGSHIP 1GB SECTION --- */\n"
    # 物理缝合用户配置，强制修正内存地址并删除所有外部依赖
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "${REPO_ROOT}/mt7981b-sl3000-emmc.dts" | \
    sed 's/0x20000000/0x40000000/g'
} > "${WORKDIR}/custom_files/mt7981b-sl3000-emmc.dts"

# 4. 旗舰工具链劫持与加速
mkdir -p "${WORKDIR}/staging_dir/host/bin" "${WORKDIR}/staging_dir/host/stamp"
for tool in m4 flex bison lex; do
    ln -sf "/usr/bin/$tool" "${WORKDIR}/staging_dir/host/bin/$tool"
    touch "${WORKDIR}/staging_dir/host/stamp/.$tool_installed"
done
touch "${WORKDIR}/staging_dir/host/.tools_install_y"

# 5. 执行 Feeds 与配置对齐
cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a
cp -fv "${REPO_ROOT}/sl3000_defconfig" .config

# 旗舰级指令注入：强制大分区 + 内存优化
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d; /CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
{
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_AUTOREMOVE=y"
} >> .config

make defconfig
echo "✅ 旗舰补丁注入完成。"
