name: build-sl3000-openwrt-2512

on:
  workflow_dispatch:

permissions:
  contents: write
  packages: write

jobs:
  build-sl3000-2512:
    runs-on: ubuntu-22.04
    timeout-minutes: 360

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          path: repo

      - name: Prepare /mnt/openwrt
        run: |
          sudo mkdir -p /mnt/openwrt
          sudo chown -R $USER:$USER /mnt

      - name: Clone ImmortalWrt 25.12
        run: git clone --depth=1 -b openwrt-25.12 https://github.com/immortalwrt/immortalwrt.git /mnt/openwrt

      - name: Install build dependencies + ccache + OpenSSL deps
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            build-essential \
            python3 python3-pip python3-setuptools python3-wheel python3-dev python3-venv \
            libffi-dev libssl-dev ccache \
            perl libperl-dev libtext-template-perl
          echo "export CCACHE_DIR=/mnt/openwrt/.ccache" >> $GITHUB_ENV
          echo "export CCACHE_COMPRESS=1" >> $GITHUB_ENV
          echo "export CCACHE_MAXSIZE=2G" >> $GITHUB_ENV

      - name: Cache ccache
        uses: actions/cache@v4
        with:
          path: /mnt/openwrt/.ccache
          key: ${{ runner.os }}-openwrt-ccache-${{ github.sha }}
          restore-keys: |
            ${{ runner.os }}-openwrt-ccache-

      - name: Clean feeds config
        working-directory: /mnt/openwrt
        run: |
          echo 'src-git packages https://github.com/openwrt/packages.git' > feeds.conf.default
          echo 'src-git luci https://github.com/openwrt/luci.git' >> feeds.conf.default
          echo 'src-git helloworld https://github.com/fw876/helloworld.git' >> feeds.conf.default
          echo 'src-git small https://github.com/kenzok8/small.git' >> feeds.conf.default

      - name: Update feeds
        working-directory: /mnt/openwrt
        run: |
          ./scripts/feeds update -a
          ./scripts/feeds install -a

      - name: Run clean-feeds.sh (white list)
        working-directory: /mnt/openwrt
        run: |
          chmod +x $GITHUB_WORKSPACE/repo/scripts/clean-feeds.sh
          bash $GITHUB_WORKSPACE/repo/scripts/clean-feeds.sh
          make defconfig

      - name: Disable menuconfig globally
        run: |
          echo "KCONFIG_NONINTERACTIVE=1" >> $GITHUB_ENV
          echo "TERM=dumb" >> $GITHUB_ENV
          echo "LC_ALL=C" >> $GITHUB_ENV
          echo "FORCE_UNSAFE_CONFIGURE=1" >> $GITHUB_ENV

      - name: Download sources (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make download -j$(nproc) || \
          (rm -rf dl/* && make download -j$(nproc))

      - name: Build host tools (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make tools/install -j$(nproc) V=s || \
          (make tools/clean && make tools/install -j$(nproc) V=s)

      - name: Build toolchain (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make toolchain/install -j$(nproc) V=s || \
          (make toolchain/clean && make toolchain/install -j$(nproc) V=s)

      - name: Build OpenSSL first (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make package/libs/openssl/compile V=s || \
          (make package/libs/openssl/clean && make package/libs/openssl/compile V=s)

      # 三件套检测
      - name: Detect three-piece consistency
        run: |
          echo "🔍 Checking DTS/MK/CONFIG consistency..."
          test -f repo/sl3000/dts/mt7981b-sl-3000-emmc.dts || (echo "❌ DTS missing" && exit 1)
          test -f repo/sl3000/mk/filogic-sl3000.mk || (echo "❌ MK missing" && exit 1)
          test -f repo/sl3000/config/sl3000.config || (echo "❌ CONFIG missing" && exit 1)

          grep -q "mediatek,mt7981" repo/sl3000/dts/mt7981b-sl-3000-emmc.dts || (echo "❌ SoC mismatch" && exit 1)
          grep -q "sl_3000-emmc" repo/sl3000/mk/filogic-sl3000.mk || (echo "❌ MK device name mismatch" && exit 1)
          grep -q "CONFIG_TARGET_DEVICE_mediatek_mt7981_DEVICE_sl_3000-emmc=y" repo/sl3000/config/sl3000.config || (echo "❌ CONFIG device missing" && exit 1)

      # 三件套注册
      - name: Apply DTS
        run: |
          mkdir -p /mnt/openwrt/target/linux/mediatek/dts
          cp repo/sl3000/dts/mt7981b-sl-3000-emmc.dts /mnt/openwrt/target/linux/mediatek/dts/

      - name: Apply MK
        run: |
          MK=/mnt/openwrt/target/linux/mediatek/image/filogic.mk
          sed -i '/Device\/sl_3000-emmc/,/endef/d' "$MK"
          sed -i '/TARGET_DEVICES += sl_3000-emmc/d' "$MK"
          cat repo/sl3000/mk/filogic-sl3000.mk >> "$MK"

      - name: Apply device config (.config)
        working-directory: /mnt/openwrt
        run: |
          rm -f .config
          cp $GITHUB_WORKSPACE/repo/sl3000/config/sl3000.config .config
          make defconfig

      - name: Build kernel (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make target/linux/compile -j$(nproc) V=s || \
          (make target/linux/clean && make target/linux/compile -j$(nproc) V=s)

      - name: Build packages (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make package/compile -j$(nproc) V=s || \
          (make package/clean && make package/compile -j$(nproc) V=s)

      - name: Build image (self-heal)
        working-directory: /mnt/openwrt
        run: |
          make target/image/compile -j$(nproc) V=s || \
          (make target/image/clean && make target/image/compile -j$(nproc) V=s)

      - name: Validate firmware output
        working-directory: /mnt/openwrt
        run: |
          ls -lh bin/targets/mediatek/mt7981/*sl_3000-emmc*sysupgrade.bin

      - name: Upload firmware
        uses: actions/upload-artifact@v4
        with:
          name: sl3000-2512-firmware
          path: /mnt/openwrt/bin/targets/mediatek/mt7981/*

      - name: Auto Release firmware
        uses: softprops/action-gh-release@v2
        if: success()
        with:
          tag_name: sl3000-openwrt-2512-${{ github.run_number }}
          name: SL3000 OpenWrt 25.12 Build #${{ github.run_number }}
          body: |
            OpenWrt 25.12 / kernel 6.6  
            Target: SL3000 (MT7981B eMMC)  
            Three-piece (DTS/MK/CONFIG) fixed  
            Build: ${{ github.run_number }}  
            Commit: ${{ github.sha }}
          files: /mnt/openwrt/bin/targets/mediatek/mt7981/*
          prerelease: true

      - name: Optimize disk space
        working-directory: /mnt/openwrt
        run: |
          echo "Cleaning build_dir, staging_dir, tmp to free disk space..."
          find dl -type f -size +100M -delete || true
          rm -rf build_dir/* staging_dir/* tmp/*
          echo "Remaining firmware size:"
          du -sh bin/targets
