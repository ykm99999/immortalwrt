#!/bin/bash
# ============================================================
# SL3000 V22.0 旗舰版：[延续 V20 逻辑 + 修复路径深度]
# ============================================================
set -e

echo ">>> [SL3000 V22.0] 启动注入任务..."

# --- 1. 定位资产 ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 注入与路径对齐 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [对齐] 正在转换 DTS 为内核原生路径格式..."
# 绝杀修复：
# 1. 内核编译时，<dt-bindings/...> 这种尖括号引用由内核搜索路径处理，不要动它。
# 2. 只有引用同目录的 mt7981.dtsi 时，必须使用双引号。
sed -e 's/#include <mediatek\/mt7981.dtsi>/#include "mt7981.dtsi"/g' \
    -e 's/#include "mediatek\/mt7981.dtsi"/#include "mt7981.dtsi"/g' \
    -e 's/#include <mediatek\/mt7981b.dtsi>/#include "mt7981b.dtsi"/g' \
    -e 's/#include "mediatek\/mt7981b.dtsi"/#include "mt7981b.dtsi"/g' \
    "$DTS_SRC" | tr -d '\r' > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 注册 Makefile
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动与 Feeds (延续) ---
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 修正 feeds 并 update
git config --global --unset url."https://github.com/".insteadOf || true
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a && ./scripts/feeds install -a
make defconfig
echo "✅ [任务完成] V22.0 注入成功！"
