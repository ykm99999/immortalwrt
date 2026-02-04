#!/bin/bash
set -e

echo ">>> [SL3000 Final-Standard] 启动硬路径物理缝合..."

# --- 1. 定位资源 ---
ROOT_DIR=$(pwd)
# 确保 SRC_DIR 精准指向克隆下来的 custom-repo
SRC_DIR="${GITHUB_WORKSPACE}/custom-repo"

# 硬编码标准路径 (ImmortalWrt 固定目录结构)
# 优先查找 6.12 目录，备选 6.6
ORIGIN_DTSI="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/mt7981.dtsi"
[ ! -f "$ORIGIN_DTSI" ] && ORIGIN_DTSI="target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/mt7981.dtsi"

# 确定目标写入目录
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"
DTS_DEST="$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 定位你的 DTS (增加容错定位)
DTS_SRC=$(find "$SRC_DIR" -type f -name "*sl3000*.dts" | head -n 1)

# --- 2. 工具劫持 (延续成功逻辑) ---
echo "🔗 执行工具链劫持..."
mkdir -p staging_dir/host/bin staging_dir/host/stamp
for tool in m4 flex bison; do
    ln -snf /usr/bin/$tool staging_dir/host/bin/$tool
done
touch staging_dir/host/.tools_install_y staging_dir/host/stamp/.tools_compile_y staging_dir/host/stamp/.m4_installed

# --- 3. 物理缝合 (修复 sed "can't read" 错误) ---
if [ -f "$ORIGIN_DTSI" ] && [ -f "$DTS_SRC" ]; then
    echo "🛠️ 正在缝合: $ORIGIN_DTSI + $DTS_SRC"
    {
        echo '/dts-v1/;'
        echo '#include <dt-bindings/leds/common.h>'
        echo '#include <dt-bindings/input/input.h>'
        # 提取基础 DTSI 内容 (过滤掉重复的头)
        sed -E '/\/dts-v1\/;|#include/d' "$ORIGIN_DTSI"
        echo -e "\n/* --- SL3000 1GB CUSTOM SECTION --- */\n"
        # 提取你的自定义 DTS 内容
        tr -d '\r' < "$DTS_SRC" | sed -E '/\/dts-v1\/;|#include/d'
    } > "$DTS_DEST"
    echo "✅ DTS 物理缝合完成: $DTS_DEST"
else
    echo "❌ 致命错误: 找不到关键 DTS 文件!"
    echo "检查点 1 (源码 DTSI): $ORIGIN_DTSI"
    echo "检查点 2 (用户 DTS): $DTS_SRC"
    # 输出当前目录结构辅助调试
    ls -R target/linux/mediatek/files-* 2>/dev/null | head -n 20
    exit 1
fi

# --- 4. 配置注入与 Feeds ---
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/feeds install jq

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
