#!/bin/bash
set -e

# 1. 路径定位
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}" # 🎯 资产就在根目录

echo "💎 [SL3000] 开始应用补丁 (从根目录读取资产)..."

cd "${WORKDIR}"

# 2. 更新 Feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心配置锁定 (延续 24.10 成功逻辑)
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config

# 4. 搬运根目录三件套
# 注入 .config
[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config

# 注入 filogic.mk (控制镜像生成)
mkdir -p "target/linux/mediatek/image"
[ -f "${SRC_DIR}/filogic.mk" ] && cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 🎯 修复处：DTS 搬运（确保父子目录都存在，解决 No such file）
mkdir -p "target/linux/mediatek/dts"
if [ -f "${SRC_DIR}/mt7981b-sl3000-emmc.dts" ]; then
    cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/"
    cp -fv "${SRC_DIR}/mt7981b-sl3000-emmc.dts" "target/linux/mediatek/dts/mt7981b-sl3000-emmc.dts"
fi

# 5. 生成默认配置并执行二次锁定
make defconfig
[ -f "${SRC_DIR}/sl3000.config" ] && cat "${SRC_DIR}/sl3000.config" >> .config
# 强制分区大小 512MB (与 128MB Factory 规格对齐)
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ [SL3000] clean-feeds.sh 补丁执行完毕。"
