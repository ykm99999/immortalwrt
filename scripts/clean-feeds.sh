#!/bin/bash
set -e

echo ">>> [SL3000 旗舰版] 启动核心注入系统 V7.5 (Full-Stack Production)"

# --- 1. 环境初始化 ---
[ -z "$GITHUB_WORKSPACE" ] && GITHUB_WORKSPACE=$(cd ..; pwd)
SRC_DIR="${GITHUB_WORKSPACE}/custom-config"
TOPDIR=$(pwd)

# --- 2. DTS 物理路径全覆盖 (解决 6.12 内核编译路径报错) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

echo ">>> [对齐] 执行多维 DTS 路径映射与 Include 修正..."
DTS_REL_PATHS=(
    "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
    "target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"
)

for dts_path in "${DTS_REL_PATHS[@]}"; do
    mkdir -p "$(dirname "$dts_path")"
    # 强制修正设备树语法以匹配内核全局搜索路径
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$(find "$SRC_DIR" -name "mt7981b-sl3000-emmc.dts")" > "$dts_path"
done

# --- 3. 插件源注入 (Passwall 2 & Docker) ---
echo ">>> [源注入] 添加 Passwall 2 及其依赖仓库..."
# 添加 Passwall 专用源
sed -i '$a src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' feeds.conf.default
sed -i '$a src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' feeds.conf.default

./scripts/feeds update -a

# --- 4. 逻辑死锁手术 (Kconfig Surgery) ---
echo ">>> [手术] 修复 Zabbix/PHP8 循环依赖与插件冲突..."
# 1. 解开 PHP8 与 Zabbix 的死锁
if [ -d "feeds/packages/admin/zabbix" ]; then
    find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +
fi
# 2. 移除旧版冲突插件，确保 Passwall 2 干净安装
rm -rf package/feeds/luci/luci-app-passwall || true
rm -rf package/feeds/packages/net/v2ray-geodata || true
rm -rf package/feeds/helloworld/luci-app-ssr-plus || true

./scripts/feeds install -a

# --- 5. 注入工厂级配置文件 (filogic.mk) ---
cp -f "$(find "$SRC_DIR" -name "filogic.mk")" "target/linux/mediatek/image/filogic.mk"
# 确保设备 DTS 引用不带路径后缀，防止编译路径重叠
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 6. 强制补全 .config 核心参数 (Docker + 1GB RAM + eMMC) ---
cat "$(find "$SRC_DIR" -name "sl3000.config")" > .config
{
    # 基础硬件支持
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_PACKAGE_kmod-mmc=y"
    echo "CONFIG_PACKAGE_kmod-sdhci-mtk=y"
    
    # Docker 旗舰支持包
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_kmod-br-netfilter=y"
    echo "CONFIG_PACKAGE_f2fs-tools=y" # 128G eMMC 建议使用 F2FS
    
    # Passwall 2 核心插件
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
    echo "CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y"
} >> .config

make defconfig
echo ">>> [成功] V7.5 工厂级环境已就绪，Passwall 2 与 Docker 依赖已补齐！"
