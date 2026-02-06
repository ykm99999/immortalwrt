#!/bin/bash
set -e

# 获取根目录路径
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
# ✅ 严格对齐：三件套就在仓库根目录
SRC_DIR="${REPO_ROOT}"

echo "💎 [SL3000] 启动 V13.5 补丁注入 (根目录全量修复版)..."

cd "${WORKDIR}"

# 1. 清理环境，防止旧配置污染 (延续原文)
rm -rf tmp .config .config.old

# 2. 更新 Feeds (延续原文)
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心修复：强力锁定 MediaTek 架构 (延续原文)
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# 4. 载入 1GB 内存与 128M 内核分区配置 (从根目录读取原文)
if [ -f "${SRC_DIR}/sl3000_defconfig" ]; then
    cat "${SRC_DIR}/sl3000_defconfig" >> .config
fi

# 5. 注入设备镜像定义 (从根目录读取原文)
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# 6. Host 工具路径劫持 (延续 V13.5 核心修复)
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

echo "✅ 补丁注入与根目录路径对齐完成。"
