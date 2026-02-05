name: SL3000-Ultimate-Factory-V6-Cached

on:
  workflow_dispatch:

env:
  WORKDIR: openwrt

jobs:
  build:
    runs-on: ubuntu-22.04
    permissions:
      contents: write
    steps:
      - name: 1. 检出仓库
        uses: actions/checkout@v4

      - name: 2. [延续修复] 12G Swap 与 空间清理
        run: |
          sudo swapoff -a || true
          sudo rm -f /swapfile || true
          sudo docker image prune -a -f || true
          sudo fallocate -l 12G /swapfile
          sudo chmod 600 /swapfile
          sudo mkswap /swapfile
          sudo swapon /swapfile

      - name: 3. [延续修复] 环境补全与源码下载
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential clang flex bison gawk gettext \
            grep patch diffutils file findutils coreutils util-linux \
            gzip bzip2 unzip wget perl python3 python3-setuptools \
            libncurses5-dev libssl-dev libelf-dev zlib1g-dev \
            device-tree-compiler bc dos2unix rsync qemu-utils fakeroot
          git clone --depth=1 -b openwrt-25.12 https://github.com/immortalwrt/immortalwrt.git ${{ env.WORKDIR }}

      # --- 数字化缓存机制开始 ---
      - name: 4. [数字化缓存] 捕获工具链哈希
        id: cache-hash
        run: |
          # 只要你的 config 或 mk 文件变动，缓存就会失效重刷
          echo "hash=${{ hashFiles('sl3000_defconfig', 'filogic.mk', 'scripts/clean-feeds.sh') }}" >> $GITHUB_OUTPUT

      - name: 5. [数字化缓存] 恢复/存储编译缓存
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.WORKDIR }}/staging_dir/host
            ${{ env.WORKDIR }}/staging_dir/toolchain-*
            ${{ env.WORKDIR }}/build_dir/host
            ${{ env.WORKDIR }}/build_dir/toolchain-*
          key: ${{ runner.os }}-openwrt-cache-${{ steps.cache-hash.outputs.hash }}
          restore-keys: |
            ${{ runner.os }}-openwrt-cache-
      # --- 数字化缓存机制结束 ---

      - name: 6. [全量集成] 执行数字化注入与劫持
        run: |
          chmod +x scripts/clean-feeds.sh
          ./scripts/clean-feeds.sh 2>&1 | tee build.log

      - name: 7. [延续修复] 工具链静默预编译 (跳过已缓存部分)
        working-directory: ${{ env.WORKDIR }}
        run: |
          export PATH="${{ github.workspace }}/${{ env.WORKDIR }}/staging_dir/host/bin:$PATH"
          export TERM=xterm
          # 补齐缓存可能遗漏的戳记文件
          mkdir -p staging_dir/host/stamp && touch staging_dir/host/.prereq-build
          make oldconfig
          # 如果缓存命中，tools 和 toolchain 会检测到已安装并快速跳过
          make tools/install -j$(nproc) FORCE=1
          make toolchain/install -j$(nproc) FORCE=1

      - name: 8. [数字化锁死] 内核源码物理硬注入
        working-directory: ${{ env.WORKDIR }}
        run: |
          make target/linux/prepare -j$(nproc)
          K_DTS_DIR=$(find build_dir -path "*/arch/arm64/boot/dts/mediatek" -type d | head -n 1)
          if [ -n "$K_DTS_DIR" ]; then
            cp -fv ../mt7981b-sl3000-emmc.dts "$K_DTS_DIR/"
            sed -i '/mt7981b-sl3000-emmc.dtb/d' "$K_DTS_DIR/Makefile"
            sed -i '/dtb-$(CONFIG_ARCH_MEDIATEK)/a \dtb-$(CONFIG_ARCH_MEDIATEK) += mt7981b-sl3000-emmc.dtb' "$K_DTS_DIR/Makefile"
          fi

      - name: 9. [终极产出] 强制全量编译
        working-directory: ${{ env.WORKDIR }}
        run: |
          export PATH="${{ github.workspace }}/${{ env.WORKDIR }}/staging_dir/host/bin:$PATH"
          export TERM=xterm
          make target/linux/compile -j$(nproc) V=s || make target/linux/compile -j1 V=s
          make package/compile -j$(nproc)
          make target/install -j$(nproc)
          
          mkdir -p ../outputs
          find bin/targets/ -name "*sl3000-emmc*" -exec cp -v {} ../outputs/ \;
          [ -d "../outputs" ] && cd ../outputs && sha256sum * > sha256sums || true

      - name: 10. 发布数字化旗舰固件
        uses: softprops/action-gh-release@v2
        if: success()
        with:
          tag_name: SL3000-DIGITAL-CACHED-${{ github.run_id }}
          files: outputs/*
          token: ${{ secrets.GITHUB_TOKEN }}
