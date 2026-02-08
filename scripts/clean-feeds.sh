#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "🚀 [SL3000] 启动 OpenWrt 25.12 最终修正版补丁..."

cd "${WORKDIR}"

# 1. 环境清理与 Feeds 同步 (延续)
./scripts/feeds update -a && ./scripts/feeds install -a
rm -rf tmp .config

# 2. 基础架构锁定
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 3. 核心资产物理注入 (延续)
# 这一步将文件放入源码树，等待 Workflow 在编译时分发
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
mkdir -p "target/linux/mediatek/dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

# ⚠️ [关键修复] 已删除破坏 Makefile 语法的 sed 替换命令
# 我们将在 Workflow 中通过 /usr/bin/fwtool 软链接来解决路径问题

# 4. 工具链修复 (延续)
mkdir -p "staging_dir/host/bin"
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool"
done

# 5. 配置生成与锁定
# 先生成默认配置
make defconfig

# 🎯 [双重锁定] 再次追加自定义配置，防止 defconfig 自动剔除
cat "${SRC_DIR}/sl3000.config" >> .config
# 锁定 RootFS 大小
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ 补丁注入完成（已移除危险的 Makefile 修改操作）。"
