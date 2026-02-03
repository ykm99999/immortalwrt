#!/bin/bash
# ============================================================
# SL3000 V18.0 旗舰版：全路径硬关联修复版
# ============================================================
set -e

echo ">>> [SL3000 V18.0] 启动物理注入任务..."

# --- 1. 定位源文件 (改用环境变量获取绝对路径) ---
# 这些变量将由 GitHub Workflow 传入
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# 校验文件是否存在，防止再次静默失败
[ ! -f "$DTS_SRC" ] && { echo "❌ 错误: 找不到 DTS 源文件: $DTS_SRC"; exit 1; }
[ ! -f "$MK_SRC" ] && { echo "❌ 错误: 找不到 MK 源文件: $MK_SRC"; exit 1; }
[ ! -f "$CONF_SRC" ] && { echo "❌ 错误: 找不到 Config 源文件: $CONF_SRC"; exit 1; }

# --- 2. 注入 DTS 并注册到内核 Makefile ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [自愈] 修正 DTS 引用并注册到内核编译列表..."
tr -d '\r' < "$DTS_SRC" > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts.tmp"
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts.tmp" > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"
rm -f "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts.tmp"

K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动补丁与 Makefile 注入 ---
echo ">>> [注入] 覆盖 filogic.mk 并补足驱动..."
# 先注入 eMMC/F2FS 驱动补丁到本地 MK
sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 配置合并与 Feeds 自愈 ---
echo ">>> [Feeds] 正在重构并强制同步插件源..."
cat "$CONF_SRC" > .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 强制使用 HTTPS 替换 Git 协议
git config --global url."https://github.com/".insteadOf git://github.com/
sed -i '/passwall/d' feeds.conf.default
echo "src-git-full passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git-full passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [任务完成] V18.0 物理注入成功！"
