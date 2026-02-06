#!/bin/bash
set -e

# 获取仓库根目录
REPO_ROOT=$1
WORKDIR="${REPO_ROOT}/openwrt"

echo "💎 [SL3000] 启动终极集成修复程序..."
echo "✅ 目标版本：OpenWrt 24.10"
echo "✅ 核心逻辑：延续 1GB RAM / 1024M Rootfs 成功案例配置"

# --- 1. 物理注入镜像生成规则 (锁定你的 filogic.mk) ---
echo "⚙️ [1/5] 正在物理注入镜像规则文件..."
mkdir -p "${WORKDIR}/target/linux/mediatek/image"
# 强行覆盖官方文件，确保 pad-to 134217728 生效
cp -fv -f "${REPO_ROOT}/filogic.mk" "${WORKDIR}/target/linux/mediatek/image/filogic.mk"

# --- 2. 工具链环境锚定 (延续历史修复) ---
echo "⚙️ [2/5] 正在建立工具链物理软链接..."
mkdir -p "${WORKDIR}/staging_dir/host/bin"
# 解决 24.10 编译过程中可能出现的工具找不到导致的 Error 1/2
for tool in m4 flex bison lex grep sed xargs getconf patch diff seq realpath stat gzip unzip bzip2 wget install perl file python python3; do
    SYS_PATH=$(which $tool || which "${tool}3" || echo "/usr/bin/$tool")
    if [ -n "$SYS_PATH" ]; then
        ln -sf "$SYS_PATH" "${WORKDIR}/staging_dir/host/bin/$tool"
    fi
done

# --- 3. 依赖包深度清理 (延续 PHP/Zabbix 修复项) ---
echo "⚙️ [3/5] 正在执行 Feeds 更新与依赖冲突切除..."
cd "${WORKDIR}"
./scripts/feeds update -a
# 彻底删除导致 24.10 编译中断的臃肿包/旧版包
rm -rf feeds/packages/lang/php* rm -rf feeds/packages/admin/zabbix
rm -rf feeds/packages/net/hs20
rm -rf feeds/packages/net/onionshare-cli
./scripts/feeds install -a

# --- 4. 数字化对齐：配置文件注入与分区强行锁死 ---
echo "⚙️ [4/5] 正在执行数字化对齐 (128M Kernel / 1024M Rootfs)..."
if [ -f "${REPO_ROOT}/sl3000.config" ]; then
    cp -fv -f "${REPO_ROOT}/sl3000.config" .config
else
    echo "⚠️ 警告：未在根目录找到 sl3000.config，将尝试使用现有 .config"
fi

# 🔥 核心防御逻辑：在 .config 尾部再次强行写入分区参数
# 这样做是为了防止 ./scripts/feeds install 过程中自动重置了分区大小
sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d' .config
sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
{
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=128"
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=1024"
} >> .config

# --- 5. 配置激活与最终校验 ---
echo "⚙️ [5/5] 正在执行最终配置同步 (oldconfig)..."
# 自动确认所有新出现的配置项，防止编译中途停顿
yes "" | make oldconfig
make defconfig

echo "🚀 [SUCCESS] 所有修复项已全量载入，环境准备就绪！"
