#!/bin/bash
set -e

echo ">>> [SL3000 BRUTE-FORCE V5] 正在执行全代码注入..."

# --- 1. 定位资源 ---
SRC_DIR="${GITHUB_WORKSPACE}/custom-repo"
# 找到你发给我的这段 DTS 文件
DTS_SRC=$(find "$SRC_DIR" -type f -name "*sl3000*.dts" | head -n 1)

# 暴力创建目标路径
DTS_DEST_DIR="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"
DTS_DEST="$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# --- 2. 暴力清洗 DTS (消除所有 include 依赖) ---
echo "🛠️ 正在将 DTS 转换为独立版..."
{
    echo '/dts-v1/;'
    # 注入必备的内核常量定义，不再引用外部 dtsi
    echo '#include <dt-bindings/leds/common.h>'
    echo '#include <dt-bindings/input/input.h>'
    echo '#include <dt-bindings/interrupt-controller/arm-gic.h>'
    echo '#include <dt-bindings/clock/mt7981-clk.h>'
    echo '#include <dt-bindings/gpio/gpio.h>'
    
    # 读取你的 DTS 内容，但过滤掉那行致命的 #include "mt7981b.dtsi"
    # 同时将内存 0x20000000 (512MB) 修改为 0x40000000 (1GB)
    sed -E '/mt7981b.dtsi|#include ".*"/d' "$DTS_SRC" | \
    sed 's/0x20000000/0x40000000/g'
} > "$DTS_DEST"

# --- 3. 强制覆盖镜像生成规则 (filogic.mk) ---
MK_DEST="target/linux/mediatek/image/filogic.mk"
MK_SRC=$(find "$SRC_DIR" -type f -name "filogic.mk" | head -n 1)
[ -f "$MK_SRC" ] && cp -fv "$MK_SRC" "$MK_DEST"

# --- 4. 工具劫持 ---
mkdir -p staging_dir/host/bin staging_dir/host/stamp
for tool in m4 flex bison; do
    ln -snf /usr/bin/$tool staging_dir/host/bin/$tool
done
touch staging_dir/host/.tools_install_y staging_dir/host/stamp/.tools_compile_y

# --- 5. 配置锁定与 Feeds ---
./scripts/feeds update -a && ./scripts/feeds install -a
cat <<EOT > .config
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOT
make defconfig
