#!/bin/bash
# ============================================================
# SL3000 V26.0 终极缝合版：针对功能完整版 DTS 深度定制
# ============================================================
set -e

echo ">>> [SL3000 V26.0] 启动深度物理缝合逻辑..."

# --- 1. 定位资产 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. 核心：物理缝合（Flattening）DTS 依赖 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

BASE_DTSI="$DTS_DEST_DIR/mt7981.dtsi"

if [ -f "$BASE_DTSI" ]; then
    echo ">>> [物理缝合] 正在将 mt7981.dtsi 内容展开并入主文件..."
    
    # a. 提取系统头文件
    grep "dt-bindings" "$DTS_SRC" | sort | uniq > dts_merged.dts
    echo "/dts-v1/;" >> dts_merged.dts
    
    # b. 注入内核原厂基础定义 (剔除重复头标记)
    grep -v "/dts-v1/;" "$BASE_DTSI" >> dts_merged.dts
    
    # c. 注入用户自定义节点 (从 / { 开始的内容)
    sed -n '/^\/ {/,$p' "$DTS_SRC" >> dts_merged.dts
    
    # d. 彻底清理所有可能冲突的 include 行
    sed -i '/#include <mediatek\/mt7981.dtsi>/d' dts_merged.dts
    sed -i '/#include "mt7981.dtsi"/d' dts_merged.dts

    mv dts_merged.dts "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
    echo "✅ [成功] DTS 已转化为独立的全量源码文件。"
else
    echo "❌ [错误] 在 $DTS_DEST_DIR 找不到基础文件 mt7981.dtsi"
    exit 1
fi

# --- 3. 注册机型与 Makefile ---
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# 修正 filogic.mk：添加必要的内核模块支持
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools kmod-mt7531/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# 写入配置
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# Feeds 逻辑同步
./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig
echo "✅ [任务完成] V26.0 注入与自愈全部成功！"
