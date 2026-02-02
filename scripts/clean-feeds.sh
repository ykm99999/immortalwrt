#!/bin/bash
set -e

echo ">>> [SL3000 旗舰版] 启动核心注入系统 V9.0 (Production Ready)"

# --- 1. 路径锚定 ---
# REPO_ROOT 是你整个 GitHub 仓库的根目录
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo ">>> 仓库根目录: $REPO_ROOT"

# --- 2. 深度精准搜索 ---
# 我们在非 openwrt 目录下搜索你的配置文件
# 即使你放在 target/linux/mediatek/... 下，只要不在 openwrt 源码文件夹内就能搜到
DTS_SRC=$(find "$REPO_ROOT" -type f -name "*mt7981b-sl3000-emmc.dts" -not -path "*/openwrt/*" | head -n 1)
MK_SRC=$(find "$REPO_ROOT" -type f -name "filogic.mk" -not -path "*/openwrt/*" | head -n 1)
CONF_SRC=$(find "$REPO_ROOT" -type f -name "*sl3000.config" -not -path "*/openwrt/*" | head -n 1)

# 诊断检查
if [ -z "$DTS_SRC" ] || [ -z "$MK_SRC" ] || [ -z "$CONF_SRC" ]; then
    echo "FATAL: 无法在仓库中定位配置文件！"
    echo "当前仓库文件树概要:"
    find "$REPO_ROOT" -maxdepth 4 -not -path '*/.*' -not -path '*/openwrt/*'
    exit 1
fi

echo ">>> 已锁定源文件: $DTS_SRC"

# --- 3. 确定 OpenWrt 源码内部目标路径 ---
# 自动识别内核版本目录 (例如 files-6.6 或 files-6.12)
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
echo ">>> 目标内核目录: $K_DIR"

# --- 4. 物理注入与 Include 修正 ---
echo ">>> [注入] 正在同步设备树并修正语法..."
DTS_TARGETS=(
    "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"
)

for target in "${DTS_TARGETS[@]}"; do
    mkdir -p "$(dirname "$target")"
    # 将 DTS 内部的 #include "..." 转换为内核标准的 <mediatek/...> 格式，防止编译中断
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$DTS_SRC" > "$target"
done

# --- 5. Makefile 与 核心配置覆盖 ---
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
# 确保 Makefile 指向标准的设备名
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 6. Feeds 自动化管理 (Passwall 2 & Docker) ---
echo ">>> [Feeds] 注入 Passwall 2 与 Docker 依赖..."
sed -i '$a src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' feeds.conf.default
sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default

./scripts/feeds update -a
# 修复 Zabbix/PHP8 循环依赖
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

rm -rf package/feeds/luci/luci-app-passwall || true
./scripts/feeds install -a

# --- 7. .config 最终强制对齐 (适配 1GB RAM) ---
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
} >> .config

make defconfig
echo ">>> [成功] V9.0 注入完成，环境已就绪！"
