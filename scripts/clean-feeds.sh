#!/bin/bash
# ============================================================
# SL3000 V20.0 旗舰版：[延续 V19 逻辑 + 修复 DTB 编译报错]
# ============================================================
set -e

echo ">>> [SL3000 V20.0] 启动注入任务..."

# --- 1. 定位资产 (延续 V19) ---
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. DTS 注入与本地化自愈 (核心修复点) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [修复] 强制平铺 DTS 引用路径，解决 Error 1..."
# 将所有 <mediatek/xxx.dtsi> 转换为同目录下的 "xxx.dtsi"
sed -e 's/#include <mediatek\/mt7981.dtsi>/#include "mt7981.dtsi"/g' \
    -e 's/#include "mediatek\/mt7981.dtsi"/#include "mt7981.dtsi"/g' \
    -e 's/#include <mediatek\/mt7981b.dtsi>/#include "mt7981b.dtsi"/g' \
    -e 's/#include "mediatek\/mt7981b.dtsi"/#include "mt7981b.dtsi"/g' \
    "$DTS_SRC" | tr -d '\r' > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 延续 V19：在内核 Makefile 注册
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动补丁与 MK 注入 (延续 V19) ---
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 配置合并与 Feeds 优化 (延续 V19) ---
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

git config --global --unset url."https://github.com/".insteadOf || true
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a && ./scripts/feeds install -a
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [任务完成] V20.0 注入与自愈成功！"
