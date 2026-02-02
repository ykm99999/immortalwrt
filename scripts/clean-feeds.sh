#!/bin/bash
set -e

echo ">>> [SL3000 旗舰版] 启动核心注入系统 V10.1 (Stable Production)"

# --- 1. 路径锚定与文件锁定 ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS_SRC=$(find "$REPO_ROOT" -type f -name "*mt7981b-sl3000-emmc.dts" -not -path "*/openwrt/*" | head -n 1)
MK_SRC=$(find "$REPO_ROOT" -type f -name "filogic.mk" -not -path "*/openwrt/*" | head -n 1)
CONF_SRC=$(find "$REPO_ROOT" -type f -name "*sl3000.config" -not -path "*/openwrt/*" | head -n 1)

if [ -z "$DTS_SRC" ] || [ -z "$MK_SRC" ] || [ -z "$CONF_SRC" ]; then
    echo "FATAL: 无法定位配置文件，请检查仓库目录！"
    exit 1
fi

# --- 2. 注入 DTS 设备树 (适配 Kernel 6.12) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

echo ">>> 正在注入 DTS 到: $K_DIR"
DTS_TARGETS=(
    "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"
)

for target in "${DTS_TARGETS[@]}"; do
    mkdir -p "$(dirname "$target")"
    # 自动转换 include 格式以符合内核编译标准
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$DTS_SRC" > "$target"
done

# --- 3. 注入编译脚本与 Makefile ---
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 4. 修复 Git 验证并配置 Feeds ---
echo ">>> [Feeds] 正在重置并注入插件源..."

# 解决 Actions 环境下可能存在的 Git 权限误报
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://".insteadOf git://

# 清理现有的冲突源，重新生成 feeds.conf.default
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

# 更新并安装 Feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 修复 php8 依赖逻辑锁 (Zabbix 相关)
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

# --- 5. .config 最终覆盖 ---
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
} >> .config

make defconfig
echo ">>> [成功] 环境已全部就绪，可以开始编译。"
