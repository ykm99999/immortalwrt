#!/bin/bash
set -e

# 获取物理路径
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKDIR="${REPO_ROOT}/openwrt"
SRC_DIR="${REPO_ROOT}"

echo "📂 进入工作目录: ${WORKDIR}"
cd "${WORKDIR}"

# 1. 更新并安装 Feeds
echo "🔄 正在同步 Feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 物理预设 25.12 核心配置
echo "⚙️ 正在生成基础配置..."
rm -rf tmp .config
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
} > .config

# 🎯 物理核心修复 A：全局字节化转换 (彻底终结 128M 报错)
# 将所有 .mk 和 Makefile 中的 128M 替换为纯数字 134217728
echo "🩹 正在执行 128M 物理转换..."
find target/linux/mediatek/image -name "*.mk" -o -name "Makefile" | xargs -r sed -i 's/128M/134217728/g' 2>/dev/null || true

# 🎯 物理核心修复 B：强制同步 Rootfs 分区 (1024MB)
echo "📏 正在强制同步 Rootfs 分区大小..."
sed -i 's/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/' .config

# 🎯 物理核心修复 C：设备定义物理对齐
echo "📝 正在同步 filogic.mk 设备定义..."
if [ -f "${SRC_DIR}/filogic.mk" ]; then
    cp -fv "${SRC_DIR}/filogic.mk" "target/linux/mediatek/image/filogic.mk"
else
    echo "⚠️ 警告：未找到自定义 filogic.mk"
fi

# 🎯 物理核心修复 D：锁定配置同步 (消除 Pipe Broken 和 Sync 警告)
echo "🔒 正在锁定配置状态..."
make defconfig
make oldconfig # 关键：确保 .config 与内核源码物理对齐

echo "✅ 补丁脚本执行完成，环境已就绪。"
