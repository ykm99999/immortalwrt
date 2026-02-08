#!/bin/bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
# 🎯 物理对齐：确保从你的 custom-config 目录读取资产
SRC_DIR="${REPO_ROOT}/custom-config"

echo "💎 [SL3000] 开始应用 25.12 全量修复补丁 (延续 24.10 成功逻辑)..."

cd "${WORKDIR}"
./scripts/feeds update -a && ./scripts/feeds install -a

# 1. 核心配置锁定 (完全延续 24.10 成功写法)
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config
[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config

# 2. 注入资产 (延续注入逻辑)
mkdir -p "target/linux/mediatek/dts"
cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 3. 工具链链接保底 (延续 24.10 修复项)
mkdir -p staging_dir/host/bin
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool" || true
done

# 4. 生成默认配置并锁定分区
make defconfig
# 🎯 再次注入以防被覆盖
[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ [SL3000] 25.12 脚本补丁完成。"
