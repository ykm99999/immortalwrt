#!/bin/bash
set -e

# ✅ 路径死锁：脚本在 scripts/，三件套在根目录
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 启动 25.12 补丁注入 (基于 V13.5 脚本修正路径)..."

cd "${WORKDIR}"

# 1. 清理环境，防止旧配置污染 (延续修复)
rm -rf tmp .config .config.old

# 2. 更新 Feeds (适配 25.12)
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心修复：强力锁定 MediaTek 架构 (延续修复)
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 4. 载入配置 (✅ 路径修正：从根目录读取 sl3000.config)
if [ -f "${SRC_DIR}/sl3000.config" ]; then
    cat "${SRC_DIR}/sl3000.config" >> .config
fi

# 5. 注入设备镜像定义 (✅ 路径修正：从根目录读取 filogic.mk)
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 6. Host 工具路径劫持 (延续修复 bison/m4/flex 报错)
mkdir -p "staging_dir/host/bin"
ln -sf "/usr/bin/m4" "staging_dir/host/bin/m4"
ln -sf "/usr/bin/flex" "staging_dir/host/bin/flex"
ln -sf "/usr/bin/bison" "staging_dir/host/bin/bison"
touch "staging_dir/host/.tools_install_y"

# 7. 生成最终配置
make defconfig

# 8. 架构校验
if grep -q "CONFIG_TARGET_x86=y" .config; then
    echo "❌ 架构锁定失败！" && exit 1
fi

echo "✅ 补丁注入与架构锁定完成。"
