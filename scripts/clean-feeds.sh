#!/bin/bash
echo ">>> [SL3000 工厂模式 V11.0] 启动深度注入..."

# --- 1. 定位三件套 ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS_SRC=$(find "$REPO_ROOT" -type f -name "*mt7981b-sl3000-emmc.dts" -not -path "*/openwrt/*" | head -n 1)
MK_SRC=$(find "$REPO_ROOT" -type f -name "filogic.mk" -not -path "*/openwrt/*" | head -n 1)
CONF_SRC=$(find "$REPO_ROOT" -type f -name "*sl3000.config" -not -path "*/openwrt/*" | head -n 1)

# --- 2. 深度语法与匹配巡检 ---
echo ">>> [巡检] 正在进行三件套深度扫描..."

# DTS 语法检查 (模拟环境)
mkdir -p ./tmp_dts
cp "$DTS_SRC" ./tmp_dts/check.dts
if ! dtc -I dts -O dtb -o /dev/null "$DTS_SRC" 2>/dev/null; then
    echo "❌ 严重错误: DTS 语法未通过！请检查分号或括号。"
    exit 1
fi

# 检查 eMMC 驱动是否在 Makefile 中定义
if ! grep -q "kmod-mtk-sd" "$MK_SRC"; then
    echo "⚠️  提醒: Makefile 中缺少关键 SD/eMMC 驱动，已自动补全。"
    sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-mtk-sd/' "$MK_SRC"
fi

# --- 3. 物理注入与内核对齐 ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

echo ">>> [注入] 同步到内核路径: $K_DIR"
# 修正 DTS 内部头文件引用路径为内核标准格式
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "$DTS_SRC" > "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"

cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 插件源强制修复 (Git 协议转换) ---
git config --global url."https://github.com/".insteadOf git://github.com/
git config --global url."https://github.com/".insteadOf git@github.com:

sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a || echo "Warning: 部分 Feed 更新失败，继续执行..."
./scripts/feeds install -a

# --- 5. 旗舰版配置合并 ---
cat "$CONF_SRC" > .config
{
    # 强制 1GB 内存对齐
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    # 强制开启 GPT 分区支持 (128GB eMMC 必备)
    echo "CONFIG_EFI_PARTITION=y"
    # 集成旗舰功能包
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
    echo "CONFIG_PACKAGE_kmod-fs-f2fs=y"
} >> .config

# 修复递归依赖冲突
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

make defconfig
echo "✅ [旗舰版环境就绪]"
