#!/bin/bash
# ============================================================
# SL3000 V17.0 旗舰版：【三件套深度物理注入+内核注册】
# ============================================================
set -e

echo ">>> [SL3000 V17.0] 启动物理注入任务..."

# --- 1. 定位源文件 ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS_SRC="$REPO_ROOT/mt7981b-sl3000-emmc.dts"
MK_SRC="$REPO_ROOT/filogic.mk"
CONF_SRC="$REPO_ROOT/sl3000.config"

# --- 2. 注入 DTS 并注册到内核 Makefile ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"
mkdir -p "$DTS_DEST_DIR"

echo ">>> [自愈] 修正 DTS 引用并注册到内核编译列表..."
# 1. 拷贝并修复 DTS
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "$DTS_SRC" | tr -d '\r' > "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 2. [绝杀] 物理修改内核 Makefile，强制添加你的 DTB 到编译序列
K_MAKEFILE="$DTS_DEST_DIR/Makefile"
if [ -f "$K_MAKEFILE" ]; then
    grep -q "mt7981b-sl3000-emmc.dtb" "$K_MAKEFILE" || \
    sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_MAKEFILE"
fi

# --- 3. 驱动补丁与 Makefile 注入 ---
echo ">>> [注入] 覆盖 filogic.mk 并补全驱动..."
if [ -f "$MK_SRC" ]; then
    # 强制注入驱动补丁
    sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-sdhci-mtk kmod-fs-f2fs f2fs-tools/' "$MK_SRC"
    cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
fi

# --- 4. 配置合并与 Feeds 连通性自愈 ---
echo ">>> [Feeds] 正在重构并强制同步插件源..."
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
} >> .config

# 注入 Passwall 及其依赖源
sed -i '/passwall/d' feeds.conf.default
echo "src-git-full passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git-full passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

# 循环重试更新 Feeds
for i in {1..3}; do
    ./scripts/feeds update -a && break || sleep 5
done
./scripts/feeds install -a

# 解决 PHP 递归依赖冲突
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [任务完成] 环境物理注入成功！"
