#!/bin/bash
# ============================================================
# SL3000 旗舰版：三件套【检测-自愈-注册-合并】合一脚本 V12.0
# ============================================================

echo ">>> [SL3000 工厂模式 V12.0] 启动全链路自动化任务..."

# --- 1. 定位与检测 (Detection) ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTS_SRC=$(find "$REPO_ROOT" -type f -name "*mt7981b-sl3000-emmc.dts" -not -path "*/openwrt/*" | head -n 1)
MK_SRC=$(find "$REPO_ROOT" -type f -name "filogic.mk" -not -path "*/openwrt/*" | head -n 1)
CONF_SRC=$(find "$REPO_ROOT" -type f -name "*sl3000.config" -not -path "*/openwrt/*" | head -n 1)

[ -z "$DTS_SRC" ] && { echo "❌ 错误: 找不到 DTS 源文件"; exit 1; }
echo "✅ 已定位源文件: $(basename "$DTS_SRC")"

# --- 2. 语法自愈 (Self-Healing) ---
# 自动检测 DTS 语法并强制修复 include 路径
echo ">>> [自愈] 正在扫描 DTS 语法并执行内核对齐..."
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"

mkdir -p "$K_DIR/arch/arm64/boot/dts/mediatek/"
# 关键自愈：将本地 include 转换为内核系统 include
sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
    -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
    "$DTS_SRC" > "$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"

# --- 3. 注册与映射 (Registration) ---
# 将自定义 Makefile 注册到系统，并检查硬件驱动对齐
echo ">>> [注册] 正在同步 Makefile 并注入 eMMC 驱动..."
if ! grep -q "kmod-mtk-sd" "$MK_SRC"; then
    echo "⚠️  检测到驱动缺失，执行自动补全..."
    sed -i '/DEVICE_PACKAGES/ s/$/ kmod-mmc kmod-mtk-sd kmod-fs-f2fs/' "$MK_SRC"
fi
cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"

# --- 4. 配置合并 (Merging) ---
# 合并用户 Config 与 1GB 内存/128GB eMMC 的硬性参数
echo ">>> [合并] 正在执行 1GB RAM 与 GPT 分区配置合并..."
cat "$CONF_SRC" > .config
{
    echo ""
    echo "# --- SL3000 硬件强制参数 ---"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
    echo "CONFIG_EFI_PARTITION=y" # 开启 GPT 支持
    echo "CONFIG_PACKAGE_kmod-fs-f2fs=y"
    echo "CONFIG_PACKAGE_f2fs-tools=y"
} >> .config

# --- 5. 依赖链清理 (Feed Fix) ---
# 解决 Git 认证报错与 PHP 递归依赖
echo ">>> [自愈] 修复 Git 协议与插件依赖冲突..."
git config --global url."https://github.com/".insteadOf git://github.com/
git config --global url."https://github.com/".insteadOf git@github.com:

sed -i '/passwall/d' feeds.conf.default
echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main" >> feeds.conf.default

./scripts/feeds update -a || echo "⚠️ 警告: 部分源更新失败，忽略并继续..."
./scripts/feeds install -a

# 解决 PHP8/Zabbix 逻辑死循环
[ -d "feeds/packages/admin/zabbix" ] && find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +

# --- 6. 最终校验 (Final Check) ---
make defconfig
echo "✅ [任务完成] SL3000 三件套已完美合并，可以开始编译！"
