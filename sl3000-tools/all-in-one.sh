#!/bin/bash
set -e

#########################################
# SL3000 工程级总控脚本（25.12 / 6.12）
#########################################

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$ROOT_DIR/.."

DTS_DIR="$REPO_ROOT/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/mediatek"
DTS_FILE="$DTS_DIR/mt7981b-sl3000-emmc.dts"
MK_FILE="$REPO_ROOT/target/linux/mediatek/image/filogic.mk"
CFG_FILE="$REPO_ROOT/.config"

#########################################
# 清理函数
#########################################
clean_file() {
    local f="$1"
    [ -f "$f" ] || return 0
    sed -i 's/\r$//' "$f"
    sed -i '1s/^\xEF\xBB\xBF//' "$f"
    sed -i 's/\xC2\xA0//g' "$f"
    sed -i 's/\xE2\x80\x8B//g' "$f"
    sed -i 's/\xE2\x80\x8C//g' "$f"
    sed -i 's/\xE2\x80\x8D//g' "$f"
    tr -d '\000-\011\013\014\016-\037\177' < "$f" > "$f.clean"
    mv "$f.clean" "$f"
}

clean_all() {
    clean_file "$DTS_FILE"
    clean_file "$MK_FILE"
    clean_file "$CFG_FILE"
}

#########################################
# DTS 语法检查（cpp + dtc）
#########################################
check_dts_syntax() {
    echo "=== 🔍 DTS 语法检查（25.12 / 6.12） ==="

    KERNEL_INC=$(find "$REPO_ROOT/build_dir" -type d -path "*/linux-*/linux-*/include" | head -n 1)

    cpp -E -P -undef -nostdinc \
        -I"$DTS_DIR" \
        -I"$REPO_ROOT/target/linux/mediatek/files-6.12/include" \
        -I"$REPO_ROOT/target/linux/mediatek/files-6.12/arch/arm64/boot/dts/include" \
        -I"$REPO_ROOT/include" \
        -I"$KERNEL_INC" \
        "$DTS_FILE" \
    | dtc -I dts -O dtb \
        -Wno-unit_address_vs_reg \
        -Wno-unit_address_format \
        -Wno-simple_bus_reg \
        -o /dev/null -

    echo "✔ DTS 语法检查通过"
}

#########################################
# MK 检查
#########################################
check_mk() {
    grep -q "Device/mt7981b-sl3000-emmc" "$MK_FILE"
    grep -q "TARGET_DEVICES" "$MK_FILE"
    echo "✔ MK 检查通过"
}

#########################################
# CONFIG 检查
#########################################
check_config() {
    grep -q "CONFIG_LINUX_6_12=y" "$CFG_FILE"
    echo "✔ CONFIG 检查通过"
}

#########################################
# CHECK 模式
#########################################
run_check() {
    clean_all
    check_dts_syntax
    check_mk
    check_config
    echo "=== ✅ CHECK 完成（25.12 / 6.12） ==="
}

case "$1" in
    check) run_check ;;
    *) echo "用法: all-in-one.sh check"; exit 1 ;;
esac
