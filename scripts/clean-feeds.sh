#!/bin/bash
set -e

# 获取路径
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
# 🎯 物理对齐：你的三件套在根目录，所以这里必须指向 REPO_ROOT
SRC_DIR="${REPO_ROOT}"

echo "🚀 [SL3000] 正在注入极限版工厂补丁 (全量修复延续)..."

cd "${WORKDIR}"

# 1. [延续] Feeds 同步与安装
./scripts/feeds update -a && ./scripts/feeds install -a

# 2. [延续] 核心架构配置强制锁定
rm -rf tmp .config
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 3. [延续] 核心资产注入 (128MB对齐MK / 1GB内存DTS / 512M分区Config)
# 🎯 从根目录读取你的三件套
cat "${SRC_DIR}/sl3000.config" >> .config
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
mkdir -p "target/linux/mediatek/dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

# 4. [极限加强] 源码级绝对路径劫持：彻底根治 fwtool 找不到的问题
FWTOOL_ABS="$(pwd)/staging_dir/host/bin/fwtool"
find target/linux/mediatek/image/ -type f -name "*.mk" -exec sed -i "s|fwtool|${FWTOOL_ABS}|g" {} +

# 5. [延续] 工具链软链接修复 (bison/m4/flex)
mkdir -p "staging_dir/host/bin"
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool"
done

# 6. [延续] 512MB RootFS 空间限制 (避开溢出错误)
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ [SL3000] 补丁注入完成，所有历史修复已锁定。"
