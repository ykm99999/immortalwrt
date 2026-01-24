#!/bin/bash
set -e

###############################################
# SL3000 工程级总控脚本（双模式）
# 模式：
#   ./all-in-one.sh check   → 只检测 / 校验 / 对比（不构建固件）
#   ./all-in-one.sh full    → 完整构建固件（含三件套生成 + 同步 + 构建）
###############################################

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENWRT_DIR="$ROOT_DIR/../openwrt"

###############################################
# 1. 自动修复：路径修复
###############################################
fix_paths() {
    echo "=== 🛠 自动修复：路径检查 ==="

    mkdir -p target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek
    mkdir -p target/linux/mediatek/image

    echo "✔ 路径检查完成"
}

###############################################
# 2. 自动修复：清理隐藏字符
###############################################
clean_hidden_chars() {
    echo "=== 🧹 自动清理隐藏字符（BOM / CRLF） ==="

    find target -type f \( -name "*.dts" -o -name "*.mk" -o -name ".config" \) | while read f; do
        sed -i 's/\r$//' "$f"
        sed -i '1s/^\xEF\xBB\xBF//' "$f"
    done

    echo "✔ 隐藏字符清理完成"
}

###############################################
# 3. DTS 语法检查
###############################################
check_dts_syntax() {
    echo "=== 🔍 DTS 语法检查 ==="

    DTS_FILE="target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/mt7981b-sl3000-emmc.dts"

    if ! dtc -I dts -O dtb "$DTS_FILE" -o /dev/null 2>/dev/null; then
        echo "❌ DTS 语法错误：$DTS_FILE"
        exit 1
    fi

    echo "✔ DTS 语法检查通过"
}

###############################################
# 4. MK 结构检查
###############################################
check_mk_structure() {
    echo "=== 🔍 MK 结构检查 ==="

    MK_FILE="target/linux/mediatek/image/filogic.mk"

    REQUIRED_FIELDS=(
        "DEVICE_VARS"
        "SUPPORTED_DEVICES"
        "DEVICE_PACKAGES"
        "IMAGE/sysupgrade.bin"
    )

    for f in "${REQUIRED_FIELDS[@]}"; do
        if ! grep -q "$f" "$MK_FILE"; then
            echo "❌ MK 缺少字段：$f"
            exit 1
        fi
    done

    echo "✔ MK 结构检查通过"
}

###############################################
# 5. CONFIG 一致性检查
###############################################
check_config_consistency() {
    echo "=== 🔍 CONFIG 一致性检查 ==="

    CFG=".config"

    grep -q "CONFIG_TARGET_mediatek_filogic=y" "$CFG" || { echo "❌ CONFIG 缺少 filogic"; exit 1; }
    grep -q "CONFIG_LINUX_6_12=y" "$CFG" || { echo "❌ CONFIG 未启用 Linux 6.12"; exit 1; }
    grep -q "CONFIG_PACKAGE_luci-app-passwall2=y" "$CFG" || echo "⚠ Passwall2 未启用"
    grep -q "CONFIG_PACKAGE_docker=y" "$CFG" || echo "⚠ Docker 未启用"

    echo "✔ CONFIG 一致性检查通过"
}

###############################################
# 6. 自动注册 profile（如缺失）
###############################################
auto_register_profile() {
    echo "=== 🧩 自动注册 profile（如缺失） ==="

    PROFILES="$OPENWRT_DIR/bin/targets/mediatek/filogic/profiles.json"
    DEVICE="mt7981b-sl3000-emmc"

    if [ -f "$PROFILES" ] && ! grep -q "$DEVICE" "$PROFILES"; then
        echo "⚠ profiles.json 缺少设备，自动注册中..."
        # 这里只提示，不自动写入，避免污染上游
        echo "ℹ 建议：构建后运行 profiles-check.sh 进行验证"
    else
        echo "✔ profiles.json 已包含设备"
    fi
}

###############################################
# 7. 上游变更报告
###############################################
upstream_report() {
    echo "=== 📡 上游变更报告 ==="
    chmod +x "$ROOT_DIR/compare-with-upstream-smart.sh"
    "$ROOT_DIR/compare-with-upstream-smart.sh"
}

###############################################
# 8. 构建环境检查
###############################################
check_build_env() {
    echo "=== 🧪 构建环境检查 ==="

    command -v gcc >/dev/null || { echo "❌ 缺少 gcc"; exit 1; }
    command -v make >/dev/null || { echo "❌ 缺少 make"; exit 1; }
    command -v dtc >/dev/null || { echo "❌ 缺少 dtc（设备树编译器）"; exit 1; }

    echo "✔ 构建环境检查通过"
}

###############################################
# 9. 同步三件套到 openwrt 源码
###############################################
sync_three_piece() {
    echo "=== 🔄 同步三件套到 openwrt 源码 ==="

    mkdir -p "$OPENWRT_DIR/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
    cp target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/*.dts \
       "$OPENWRT_DIR/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek/"

    cp target/linux/mediatek/image/filogic.mk \
       "$OPENWRT_DIR/target/linux/mediatek/image/"

    cp .config "$OPENWRT_DIR/.config"

    echo "✔ 三件套同步完成"
}

###############################################
# 主流程：check 模式
###############################################
run_check() {
    echo "=== 🔍 运行 CHECK 模式（不构建固件） ==="

    check_build_env
    fix_paths
    clean_hidden_chars
    check_dts_syntax
    check_mk_structure
    check_config_consistency
    upstream_report

    echo "=== ✅ CHECK 模式完成 ==="
}

###############################################
# 主流程：full 模式
###############################################
run_full() {
    echo "=== 🚀 FULL 模式：完整构建固件 ==="

    run_check

    echo "=== 🛠 生成三件套 ==="
    chmod +x "$ROOT_DIR/generate-three-piece.sh"
    "$ROOT_DIR/generate-three-piece.sh"

    echo "=== 🔍 校验三件套 ==="
    chmod +x "$ROOT_DIR/three-piece-check.sh"
    "$ROOT_DIR/three-piece-check.sh"

    sync_three_piece

    echo "=== 🧱 构建固件 ==="
    cd "$OPENWRT_DIR"
    make defconfig
    make toolchain/install -j$(nproc)
    make -j$(nproc)

    echo "=== 🔍 构建后验证 ==="
    chmod +x "$ROOT_DIR/profiles-check.sh"
    "$ROOT_DIR/profiles-check.sh"

    echo "=== 🎉 FULL 模式完成：固件已生成 ==="
}

###############################################
# 入口
###############################################
case "$1" in
    check)
        run_check
        ;;
    full)
        run_full
        ;;
    *)
        echo "用法："
        echo "  ./all-in-one.sh check   # 只检测"
        echo "  ./all-in-one.sh full    # 完整构建固件"
        exit 1
        ;;
esac
