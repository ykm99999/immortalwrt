#!/bin/bash
# ============================================================
# SL3000 V21.0 旗舰版：[延续 V20 逻辑 + 预编译全量化 DTS]
# ============================================================
set -e

echo ">>> [SL3000 V21.0] 启动全量化注入任务..."

# --- 1. 定位资产 (延续 V19/20) ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 全量化合并 (核心修复点：解决 No such file or directory) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [全量化] 正在将 .dtsi 依赖强行合并至主 DTS 文件..."
# 使用 GCC 预处理器处理 DTS：将所有 #include 展开为实际内容
# -I 参数确保 GCC 能找到内核自带的 mt7981.dtsi 等文件
gcc -E -nostdinc -x assembler-with-cpp \
    -I "$DTS_DEST_DIR" \
    -I "$K_DIR/arch/arm64/boot/dts" \
    -o "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts.tmp" "$DTS_SRC"

# 清理 GCC 产生的调试行（以 # 开头的行），生成纯净的独立 DTS
grep -v '^#' "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts.tmp" > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
rm -f "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts.tmp"

# 延续 V20：在内核 Makefile 注册
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动补丁与 MK 注入 (延续 V20) ---
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 配置合并与 Feeds 优化 (延续 V20) ---
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

git config --global --unset url."https://github.com/".insteadOf || true
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a && ./scripts/feeds install -a
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [任务完成] V21.0 全量化注入与自愈成功！"
