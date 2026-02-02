#!/bin/bash
# 注意：这里去掉了 set -e，允许某些不重要的 feed 更新失败时不中断脚本
echo ">>> [SL3000 旗舰版] 启动核心注入系统 V10.3 (Auth-Fix Edition)"

# --- 1. 定位并注入文件 (你已经跑通的部分) ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS_SRC=$(find "$REPO_ROOT" -type f -name "*mt7981b-sl3000-emmc.dts" -not -path "*/openwrt/*" | head -n 1)
MK_SRC=$(find "$REPO_ROOT" -type f -name "filogic.mk" -not -path "*/openwrt/*" | head -n 1)
CONF_SRC=$(find "$REPO_ROOT" -type f -name "*sl3000.config" -not -path "*/openwrt/*" | head -n 1)

K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

echo ">>> 注入核心文件到: $K_DIR"
mkdir -p "$K_DIR/arch/arm64/boot/dts/mediatek/"
# 修正 DTS 内部 include 路径
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "$DTS_SRC" > "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"

cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 2. 强力修复 Git 认证错误 ---
echo ">>> [修复] 正在配置 Git 通行证..."
# 强制所有 git:// 和 git@ 转换为 https://
git config --global url."https://github.com/".insteadOf git://github.com/
git config --global url."https://github.com/".insteadOf git@github.com:
# 禁用交互式提示
export GIT_TERMINAL_PROMPT=0

# --- 3. 插件源注入与更新 ---
echo ">>> [Feeds] 正在重置并更新插件源..."
# 清理旧的重复项
sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

# 更新 Feeds。即使报错也继续，因为基础组件已经 Clone 成功了
./scripts/feeds update -a || echo "警告：部分 Feed 更新失败，但我们将继续尝试安装..."
./scripts/feeds install -a

# --- 4. 核心 .config 最终合并 ---
echo ">>> [配置] 正在合并 1GB 内存与 128GB eMMC 配置..."
cat "$CONF_SRC" > .config
{
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_PACKAGE_luci-app-dockerman=y"
    echo "CONFIG_PACKAGE_docker-ce=y"
    echo "CONFIG_PACKAGE_luci-app-passwall=y"
} >> .config

# 修正 php8 依赖锁
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

# 最后运行 defconfig
make defconfig
echo ">>> [成功] V10.3 流程执行完毕，准备开始编译！"
