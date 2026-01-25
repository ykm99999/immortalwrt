#!/bin/bash
set -e

#########################################
# SL3000 工程级总控脚本（旗舰版，25.12 + 6.12）
#########################################

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$ROOT_DIR/.."

DTS_DIR="$REPO_ROOT/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
DTS_FILE="$DTS_DIR/mt7981b-sl3000-emmc.dts"
MK_FILE="$REPO_ROOT/target/linux/mediatek/image/filogic.mk"
CFG_FILE="$REPO_ROOT/.config"

#########################################
# 清理函数：统一清理 DTS / MK / CONFIG
#########################################
clean_file() {
    local f="$1"
    [ -f "$f" ] || return 0

    # 去掉 CRLF
    sed -i 's/\r$//' "$f"
    # 去掉 BOM
    sed -i '1s/^\xEF\xBB\xBF//' "$f"
    # 去掉常见零宽字符
    sed -i 's/\xC2\xA0//g' "$f"
    sed -i 's/\xE2\x80\x8B//g' "$f"
    sed -i 's/\xE2\x80\x8C//g' "$f"
    sed -i 's/\xE2\x80\x8D//g' "$f"
    # 去掉控制字符
    tr -d '\000-\011\013\014\016-\037\177' < "$f" > "$f.clean"
    mv "$f.clean" "$f"
}

clean_all() {
    clean_file "$DTS_FILE"
    clean_file "$MK_FILE"
    clean_file "$CFG_FILE"
}

#########################################
# DTS 语法检查（旗舰版，25.12 + 6.12）
#########################################
check_dts_syntax() {
    echo "=== 🔍 DTS 语法检查（旗舰版） ==="

    if [ ! -f "$DTS_FILE" ]; then
        echo "❌ DTS 文件不存在：$DTS_FILE"
        exit 1
    fi

    echo "--- DTS 前 20 行 ---"
    sed -n '1,20p' "$DTS_FILE"

    echo "--- DTS 前 20 行（不可见字符） ---"
    sed -n '1,20p' "$DTS_FILE" | sed -n 'l'

    echo "--- cpp 预处理 + dtc 检查 ---"

    # 尝试找到内核 include（如果还没构建过，可能为空）
    KERNEL_INC="$(find "$REPO_ROOT/build_dir" -type d -path "*/linux-*/linux-*/include" 2>/dev/null | head -n 1 || true)"

    CPP_ARGS=(
        -E -P -undef -nostdinc
        -I"$DTS_DIR"
        -I"$REPO_ROOT/target/linux/mediatek/files-6.12/include"
        -I"$REPO_ROOT/include"
    )

    # 如果找到了内核 include，就加进去；没找到也不报错
    if [ -n "$KERNEL_INC" ]; then
        CPP_ARGS+=(-I"$KERNEL_INC")
        echo "ℹ 使用内核 include: $KERNEL_INC"
    else
        echo "ℹ 未找到内核 include，使用 OpenWrt 自身 include 进行检查"
    fi

    # 真正执行 cpp + dtc
    if ! cpp "${CPP_ARGS[@]}" "$DTS_FILE" \
        | dtc -I dts -O dtb \
            -Wno-unit_address_vs_reg \
            -Wno-unit_address_format \
            -Wno-simple_bus_reg \
            -o /dev/null - 2>&1
    then
        echo "❌ DTS 语法检查失败"
        exit 1
    fi

    echo "✔ DTS 语法检查通过（旗舰版）"
}

#########################################
# MK 检查（25.12 + 6.12）
#########################################
check_mk() {
    echo "=== 🔍 MK 检查 ==="

    if [ ! -f "$MK_FILE" ]; then
        echo "❌ MK 文件不存在：$MK_FILE"
        exit 1
    fi

    grep -q "Device/mt7981b-sl3000-emmc" "$MK_FILE" || {
        echo "❌ MK 中缺少 Device/mt7981b-sl3000-emmc 段"
        exit 1
    }

    grep -q "TARGET_DEVICES" "$MK_FILE" || {
        echo "❌ MK 中缺少 TARGET_DEVICES 定义"
        exit 1
    }

    echo "✔ MK 检查通过"
}

#########################################
# CONFIG 检查（25.12 + 6.12）
#########################################
check_config() {
    echo "=== 🔍 CONFIG 检查 ==="

    if [ ! -f "$CFG_FILE" ]; then
        echo "❌ CONFIG 文件不存在：$CFG_FILE"
        exit 1
    fi

    grep -q "CONFIG_TARGET_mediatek_filogic=y" "$CFG_FILE" || {
        echo "❌ CONFIG 未启用 mediatek filogic 目标"
        exit 1
    }

    grep -q "CONFIG_LINUX_6_12=y" "$CFG_FILE" || {
        echo "❌ CONFIG 未启用 Linux 6.12 内核"
        exit 1
    }

    echo "✔ CONFIG 检查通过"
}

#########################################
# CHECK 模式：不构建，只清理 + 检查
#########################################
run_check() {
    echo "=== 🧹 清理三件套 ==="
    clean_all

    check_dts_syntax
    check_mk
    check_config

    echo "=== ✅ CHECK 完成（旗舰版） ==="
}

#########################################
# FULL 模式：生成三件套 + 检查 + 构建
#########################################
run_full() {
    echo "=== 🚀 FULL 模式：生成三件套 + 检查 + 构建 ==="

    # 1. 生成三件套（你现有的真源脚本）
    chmod +x "$ROOT_DIR/generate-three-piece.sh"
    "$ROOT_DIR/generate-three-piece.sh"

    # 2. 清理 + 检查
    run_check

    # 3. 构建（25.12 + 6.12）
    cd "$REPO_ROOT"
    make defconfig
    make -j"$(nproc)"

    echo "=== 🎉 FULL 完成：固件已构建（25.12 + 6.12） ==="
}

#########################################
# 入口
#########################################
case "$1" in
    check)
        run_check
        ;;
    full)
        run_full
        ;;
    *)
        echo "用法: $0 {check|full}"
        exit 1
        ;;
esac
