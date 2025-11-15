define Device/sl-3000-emmc
  DEVICE_VENDOR := Silicon
  DEVICE_MODEL := SL-3000
  DEVICE_DTS := sl-3000-emmc
  DEVICE_PACKAGES := kmod-usb3 kmod-mmc kmod-leds-gpio kmod-gpio-button
endef
TARGET_DEVICES += sl-3000-emmc
