#!/bin/bash
set -e

echo ">>> [SL3000 V33.0] 启动全自动化修复流程..."

# --- 1. 资产定位与环境检查 ---
# 确保所有变量指向正确的物理路径
DTS_SRC="${CUSTOM_ASSETS}/mt7981b-sl3000-emmc.dts"
MK_SRC="${CUSTOM_ASSETS}/filogic.mk"
CONF_SRC="${CUSTOM_ASSETS}/sl3000.config"

# --- 2. 内核 DTS 目录重构 (核心修复) ---
# 自动寻找当前的内核版本目录 (如 files-6.12 或 files-6.6)
K_DIR=$(ls -d target/linux/mediatek/files-* 2>/dev/null | sort -V | tail -n 1)
[ -z "$K_DIR" ] && K_DIR="target/linux/mediatek/files-6.12"
DTS_DEST_DIR="$K_DIR/arch/arm64/boot/dts/mediatek"

echo "目标内核目录: $K_DIR"
mkdir -p "$DTS_DEST_DIR"

# 拷贝你的原始 DTS 文件
cp -f "$DTS_SRC" "$DTS_DEST_DIR/mt7981b-sl3000-emmc.dts"

# 【头文件引用补丁】
# 解决脚本日志中常见的 "mediatek/mt7981.dtsi: No such file" 错误
# 在当前目录下建立一个真正的 mediatek 文件夹并做软链接映射
mkdir -p "$DTS_DEST_DIR/mediatek"
find "$DTS_DEST_DIR/mediatek" -type l -delete || true # 清理旧链接防止递归
ln -sf ../*.dtsi "$DTS_DEST_DIR/mediatek/" || true

# --- 3. 设备 Makefile 覆盖 ---
# 确保 filogic.mk 包含了 Device/sl3000-emmc 的定义
if [ -f "$MK_SRC" ]; then
    cp -f "$MK_SRC" "target/linux/mediatek/image/filogic.mk"
    echo "✅ 设备定义文件已更新"
fi

# --- 4. 依赖项强行安装 (解决 V31 日志中的 jq 缺失) ---
echo "更新 Feeds 并同步缺失工具..."
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install jq

# --- 5. .config 强制校准 (解决打包找不到目录的关键) ---
# 逻辑：删除所有冲突的 Target，强行指定 SL3000 为唯一目标
echo "正在重新校准生成 .config..."

# 清理可能导致架构冲突的旧配置
sed -i '/CONFIG_TARGET/d' .config

# 注入你的预设配置
if [ -f "$CONF_SRC" ]; then
    cat "$CONF_SRC" > .config
else
    touch .config
fi

# 强制追加打包必需的硬指标 (必须与 filogic.mk 定义的 Device 名字严格对齐)
{
    echo "CONFIG_TARGET_mediatek=y"
    echo "CONFIG_TARGET_mediatek_filogic=y"
    echo "CONFIG_TARGET_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_sl3000-emmc=y"
    echo "CONFIG_TARGET_ROOTFS_SQUASHFS=y"
} >> .config

# 执行最后的配置收敛
make defconfig

echo ">>> [SL3000 V33.0] 脚本执行完毕，准备开始编译。"
