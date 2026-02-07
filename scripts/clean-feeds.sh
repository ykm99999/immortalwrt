#!/bin/bash
set -e

# 获取路径
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
# 🎯 核心纠错：你的三件套在根目录，这里必须对齐根目录
SRC_DIR="${REPO_ROOT}"

echo "🚀 [SL3000] 正在针对 25.12 注入极限版补丁 (全量修复延续)..."

cd "${WORKDIR}"

# 1. Feeds 更新
./scripts/feeds update -a && ./scripts/feeds install -a

# 2. 架构锁定
rm -rf tmp .config
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 3. 核心资产注入 (🎯 从根目录读取三件套)
cat "${SRC_DIR}/sl3000.config" >> .config
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
mkdir -p "target/linux/mediatek/dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

# 4. [极限劫持] 彻底根治 Error 127：强制锁定 fwtool 绝对路径
FWTOOL_ABS="$(pwd)/staging_dir/host/bin/fwtool"
find target/linux/mediatek/image/ -type f -name "*.mk" -exec sed -i "s|fwtool|${FWTOOL_ABS}|g" {} +

# 5. 工具链修复
mkdir -p "staging_dir/host/bin"
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool"
done

# 6. 分区空间锁定
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config
