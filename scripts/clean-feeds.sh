#!/bin/bash
set -e

echo ">>> [SL3000 Final-V8] 启动物理全量缝合方案..."

ROOT_DIR=$(pwd)
SRC_DIR="${GITHUB_WORKSPACE}/custom-repo"

# 1. 环境劫持 (加速)
mkdir -p staging_dir/host/bin staging_dir/host/stamp
for tool in m4 flex bison; do
    ln -snf /usr/bin/$tool staging_dir/host/bin/$tool
done
touch staging_dir/host/.tools_install_y staging_dir/host/stamp/.tools_compile_y

# 2. 定位资源
USER_DTS=$(find "$SRC_DIR" -type f -name "*sl3000*.dts" | head -n 1)
# 寻找系统内核里的底层定义文件
ORIGIN_DTSI=$(find target/linux/mediatek/ -name "mt7981.dtsi" | head -n 1)

# 确定目标目录
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"
DTS_DEST="$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 3. 执行物理级“全自包含”缝合
echo "🛠️ 正在将 dtsi 内容硬核注入 dts..."
{
    echo '/dts-v1/;'
    # 注入标准头
    echo '#include <dt-bindings/interrupt-controller/arm-gic.h>'
    echo '#include <dt-bindings/clock/mt7981-clk.h>'
    echo '#include <dt-bindings/gpio/gpio.h>'
    echo '#include <dt-bindings/leds/common.h>'
    echo '#include <dt-bindings/input/input.h>'
    
    # 提取并注入系统底层的 mt7981.dtsi 内容 (过滤掉它原本的头定义)
    if [ -f "$ORIGIN_DTSI" ]; then
        sed -E '/\/dts-v1\/|#include/d' "$ORIGIN_DTSI"
    fi
    
    echo -e "\n/* --- SL3000 1GB CUSTOM SECTION --- */\n"
    
    # 注入用户 DTS 内容 (物理删除报错的那行 include)
    # 并将内存从 512MB (0x20000000) 修正为 1GB (0x40000000)
    sed -E '/mt7981.dtsi|mt7981b.dtsi|#include ".*"|#include <mediatek\//d' "$USER_DTS" | \
    sed 's/0x20000000/0x40000000/g'
} > "$DTS_DEST"

# 4. 镜像生成规则补丁
MK_SRC=$(find "$SRC_DIR" -type f -name "filogic.mk" | head -n 1)
[ -f "$MK_SRC" ] && cp -fv "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# 5. Feeds & Config
./scripts/feeds update -a && ./scripts/feeds install -a
cat <<EOT > .config
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y
CONFIG_TARGET_KERNEL_PARTSIZE=128
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOT
make defconfig
