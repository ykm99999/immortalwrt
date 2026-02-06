#!/bin/bash
set -e

# ✅ 路径死锁：三件套必须在仓库根目录
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 启动 25.12 补丁注入 (延续 24.10 MK 修复逻辑)..."

cd "${WORKDIR}"

# 1. 延续修复：清理环境
rm -rf tmp .config .config.old

# 2. 延续修复：更新 Feeds
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心修复：强力锁定架构并载入配置
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

if [ -f "${SRC_DIR}/sl3000.config" ]; then
    cat "${SRC_DIR}/sl3000.config" >> .config
fi

# 4. 注入镜像定义 (✅ 载入你提供的移除 IMAGE_SIZE 限制的 filogic.mk)
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 5. 延续修复：Host 工具路径劫持
mkdir -p "staging_dir/host/bin"
ln -sf "/usr/bin/m4" "staging_dir/host/bin/m4"
ln -sf "/usr/bin/flex" "staging_dir/host/bin/flex"
ln -sf "/usr/bin/bison" "staging_dir/host/bin/bison"
touch "staging_dir/host/.tools_install_y"

# 6. 生成配置
make defconfig

echo "✅ 补丁脚本执行完成。"
