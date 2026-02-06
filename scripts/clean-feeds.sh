#!/bin/bash
set -e

# 获取根目录路径 (脚本在 scripts/，向上退一级即根目录)
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
# ✅ 路径永不变更：三件套必须在仓库根目录
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 启动 25.12 补丁注入 (使用原版脚本: clean-feeds.sh)..."

cd "${WORKDIR}"

# 1. 清理环境 (延续原方案)
rm -rf tmp .config .config.old

# 2. 更新 Feeds (适配 25.12)
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心修复：强力锁定架构 (延续原方案)
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 4. 载入配置 (✅ 严格锁定：从根目录读取 sl3000.config)
if [ -f "${SRC_DIR}/sl3000.config" ]; then
    cat "${SRC_DIR}/sl3000.config" >> .config
fi

# 5. 注入镜像定义 (✅ 严格锁定：从根目录读取 filogic.mk)
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 6. Host 工具路径劫持 (解决编译兼容性)
mkdir -p "staging_dir/host/bin"
ln -sf "/usr/bin/m4" "staging_dir/host/bin/m4"
ln -sf "/usr/bin/flex" "staging_dir/host/bin/flex"
ln -sf "/usr/bin/bison" "staging_dir/host/bin/bison"
touch "staging_dir/host/.tools_install_y"

# 7. 生成最终配置
make defconfig

echo "✅ 补丁注入完成。"
