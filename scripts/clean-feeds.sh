#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "🚀 [SL3000] 正在执行针对 25.12 的全量修复延续..."

cd "${WORKDIR}"

# 1. Feeds 同步 (延续)
./scripts/feeds update -a && ./scripts/feeds install -a

# 2. 彻底清理旧配置 (25.12 必须彻底删除 tmp)
rm -rf tmp .config

# 3. 基础架构锁定
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 4. 资产注入 (延续)
cat "${SRC_DIR}/sl3000.config" >> .config
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
mkdir -p "target/linux/mediatek/dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"

# 5. 绝对路径劫持 (延续)
FWTOOL_ABS="$(pwd)/staging_dir/host/bin/fwtool"
find target/linux/mediatek/image/ -type f -name "*.mk" -exec sed -i "s|fwtool|${FWTOOL_ABS}|g" {} +

# 6. 工具链软链接 (延续)
mkdir -p "staging_dir/host/bin"
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool"
done

# 7. 最终配置锁定
make defconfig
# 🎯 物理加固：再次注入以防 defconfig 剔除自定义配置
cat "${SRC_DIR}/sl3000.config" >> .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ [SL3000] 补丁注入完成，环境已就绪。"
