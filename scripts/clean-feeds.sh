#!/bin/bash
set -e

echo ">>> [工程体系] 启动 clean-feeds.sh V5.1 (逻辑自愈+路径轰炸版)"

# --- 1. 环境初始化 ---
# 确保在 GitHub Actions 环境或本地环境下都能准确定位源文件目录
[ -z "$GITHUB_WORKSPACE" ] && GITHUB_WORKSPACE=$(cd ..; pwd)
SRC_DIR="${GITHUB_WORKSPACE}/custom-config"

# --- 2. 动态搜索源文件 ---
DTS_SRC=$(find "$SRC_DIR" -name "mt7981b-sl3000-emmc.dts" | head -n 1)
MK_SRC=$(find "$SRC_DIR" -name "filogic.mk" | head -n 1)
CONF_SRC=$(find "$SRC_DIR" -name "sl3000.config" | head -n 1)

if [ -z "$DTS_SRC" ] || [ -z "$MK_SRC" ] || [ -z "$CONF_SRC" ]; then
    echo "FATAL: 无法在 $SRC_DIR 找到三件套源文件，请确认仓库结构"
    exit 1
fi

# --- 3. 确定并清理目标路径 (解决 cc1 找不到文件的核心) ---
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | head -n 1)
[ -z "$K_DIR" ] && { echo "ERROR: 找不到内核 files 目录"; exit 1; }

# 定义所有可能的 DTS 存放点，防止各种构建环境下的路径真空
DEST_A="$K_DIR/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"
DEST_B="target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
DEST_C="target/linux/mediatek/dts/mediatek/mt7981b-sl3000-emmc.dts"

echo ">>> [自愈] 执行全路径物理对齐与 Include 修正..."
for path in "$DEST_A" "$DEST_B" "$DEST_C"; do
    mkdir -p "$(dirname "$path")"
    # 注入时顺便修正 DTS 内部引用语法，确保 6.12 内核兼容性
    sed -e 's/#include "mt7981.dtsi"/#include <mediatek\/mt7981.dtsi>/g' \
        -e 's/#include "mt7981b.dtsi"/#include <mediatek\/mt7981b.dtsi>/g' \
        "$DTS_SRC" > "$path"
    echo "    - 已投放并修正: $path"
done

# --- 4. 注入编译配置 ---
echo ">>> [注入] 执行 MK 与 Config 注入..."
cp -v "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
mkdir -p configs && cp -v "$CONF_SRC" ".config"

# --- 5. 修正 filogic.mk 引用逻辑 ---
# 强制剥离可能导致路径解析错误的 DEVICE_DTS 定义前缀
sed -i 's/DEVICE_DTS := .*/DEVICE_DTS := mt7981b-sl3000-emmc/' target/linux/mediatek/image/filogic.mk

# --- 6. Feeds 管理与【核心修复】循环依赖 ---
echo ">>> [Feeds] 正在同步与冲突清理..."
./scripts/feeds update -a

# 【致命错误修复】打破 Zabbix 与 PHP8 的 Kconfig 循环依赖
# 将 Zabbix 里的 select (强制选中) 改为 depends on (前置依赖)，解决 Recursive dependency
if [ -d "feeds/packages/admin/zabbix" ]; then
    echo ">>> [自愈] 正在手术修复 Zabbix/PHP8 循环依赖..."
    find feeds/packages/admin/zabbix -name Makefile -exec sed -i 's/select PACKAGE_php8/depends on PACKAGE_php8/g' {} +
fi

# 清理可能导致冲突的知名包
rm -rf package/feeds/helloworld/luci-app-ssr-plus || true
./scripts/feeds install -a

# --- 7. 门禁逻辑与配置刷新 ---
echo ">>> [门禁] 执行最终一致性检查与 defconfig..."
grep -q "Device/sl3000-emmc" "target/linux/mediatek/image/filogic.mk" || { echo "MK 注入验证失败"; exit 1; }

# 强制将内存定义补正为 1GB (针对 .config)
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config || true

# 执行配置刷新，此时不会再报 PHP8 循环依赖错误
make defconfig

echo ">>> [成功] V5.1 全链路自愈完成，逻辑死锁已解除，路径已对齐！"
