#!/bin/bash
set -e

# 获取路径
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
# 🎯 物理纠错：你的资产在根目录，路径锁定为 REPO_ROOT
SRC_DIR="${REPO_ROOT}"

echo "🚀 [SL3000] 正在针对 25.12 注入极限版工厂补丁 (全量修复延续)..."

cd "${WORKDIR}"

# 1. [原文还原] Feeds 同步与安装
./scripts/feeds update -a && ./scripts/feeds install -a

# 2. [原文还原] 核心架构配置强制锁定
rm -rf tmp .config
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 3. [原文还原] 核心资产注入
cat "${SRC_DIR}/sl3000.config" >> .config
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
mkdir -p "target/linux/mediatek/dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

# 4. [原文还原] 源码级绝对路径劫持
FWTOOL_ABS="$(pwd)/staging_dir/host/bin/fwtool"
find target/linux/mediatek/image/ -type f -name "*.mk" -exec sed -i "s|fwtool|${FWTOOL_ABS}|g" {} +

# 5. [原文还原] 工具链软链接修复
mkdir -p "staging_dir/host/bin"
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool"
done

# 6. [原文还原] 512MB RootFS 空间限制
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ [SL3000] 25.12 补丁注入完成。"
