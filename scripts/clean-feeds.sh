#!/bin/bash
set -e

# ✅ 路径锁定：按照你当前仓库结构，三件套在根目录
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}" # 修改点：由 custom-config 改为根目录

echo "💎 [SL3000] 启动 25.12 全量延续修复脚本 (严禁漂移版)..."

cd "${WORKDIR}"

# [延续修复] 1. Feeds 自愈机制
echo "🔄 正在同步 Feeds 源..."
for i in {1..3}; do
    ./scripts/feeds update -a && ./scripts/feeds install -a && break || {
        echo "⚠️ Feeds 更新失败，正在重试 ($i/3)..."
        sleep 5
    }
done

# [延续修复] 2. 环境清理与架构强锁定
rm -rf tmp .config .config.old
echo "CONFIG_TARGET_mediatek=y" > .config
echo "CONFIG_TARGET_mediatek_filogic=y" >> .config
echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y" >> .config

# [延续修复] 3. 配置文件合并 (✅ 修正路径为根目录)
if [ -f "${SRC_DIR}/sl3000.config" ]; then
    cat "${SRC_DIR}/sl3000.config" >> .config
else
    echo "❌ 关键错误：丢失 sl3000.config" && exit 1
fi

# [延续修复] 4. 打包文件注入 (✅ 修正路径为根目录)
mkdir -p "target/linux/mediatek/image"
cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"

# [延续修复] 5. 工具链劫持
mkdir -p "staging_dir/host/bin"
for tool in m4 flex bison gawk; do
    ln -sf "$(which $tool)" "staging_dir/host/bin/$tool"
done
touch "staging_dir/host/.tools_install_y"

# [延续修复] 6. 空间防御逻辑：将 RootFS 强制纠偏为 512MB
make defconfig
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/' .config

echo "✅ [SL3000] 补丁注入完成。"
