#!/bin/bash
# ============================================================
# SL3000 工厂级自愈与注入脚本
# ============================================================

set -e  # 遇到任何错误立即终止

echo ">>> [步骤 1/4] 清理环境并强制注入自定义三件套..."

# 路径定义
TARGET_DIR="openwrt"
MK_DEST="$TARGET_DIR/target/linux/mediatek/image/filogic.mk"
DTS_DEST_DIR="$TARGET_DIR/target/linux/mediatek/files-6.12/arch/arm64/boot/dts"
DTS_DEST_FILE="$DTS_DEST_DIR/mediatekmt7981b-sl3000-emmc.dts"

# 1. 强制覆盖 MK 文件 (全量替换官方定义)
if [ -f "target/linux/mediatek/image/filogic.mk" ]; then
    rm -f "$MK_DEST"
    cp -f "target/linux/mediatek/image/filogic.mk" "$MK_DEST"
    echo "SUCCESS: filogic.mk 已强制覆盖"
else
    echo "ERROR: 未找到自定义 MK 文件" && exit 1
fi

# 2. DTS 注入与后缀对齐 (将 .d 转换为内核识别的 .dts)
mkdir -p "$DTS_DEST_DIR"
if [ -f "target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatekmt7981b-sl3000-emmc.d" ]; then
    rm -f "$DTS_DEST_FILE"
    cp -f "target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatekmt7981b-sl3000-emmc.d" "$DTS_DEST_FILE"
    echo "SUCCESS: DTS 已注入并修正后缀"
else
    echo "ERROR: 未找到自定义 DTS 文件" && exit 1
fi

# 3. 注入 .config
if [ -f "sl3000/config/sl3000.config" ]; then
    cp -f "sl3000/config/sl3000.config" "$TARGET_DIR/.config"
    echo "SUCCESS: 注入 SL3000 专属 .config"
fi

echo ">>> [步骤 2/4] Feeds 自动化同步与冲突修复..."
cd "$TARGET_DIR"
./scripts/feeds update -a
./scripts/feeds install -a || {
    echo "WARNING: Feeds 冲突，执行清理自愈..."
    rm -rf feeds && ./scripts/feeds update -a && ./scripts/feeds install -a
}

echo ">>> [步骤 3/4] 注册硬件定义到编译系统索引..."
make defconfig

echo ">>> [步骤 4/4] 最终一致性校验..."
if grep -q "sl3000-emmc" "target/linux/mediatek/image/filogic.mk"; then
    echo "CHECK: SL3000 硬件定义已成功注册"
else
    echo "FATAL ERROR: 注入失败，编译系统未识别型号" && exit 1
fi

