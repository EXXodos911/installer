#!/bin/bash
set -euo pipefail

# AMD CPU/GPU drivers
sudo pacman -S --noconfirm --needed vulkan-radeon mesa amd-ucode

# Bluetooth
sudo systemctl enable bluetooth.service

# Network (iwd)
sudo systemctl enable iwd.service
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

# Disable USB autosuspend to prevent peripheral disconnections
echo 'options usbcore autosuspend=-1' | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf >/dev/null

# Wireless regulatory domain
echo 'WIRELESS_REGDOM=IL' | sudo tee -a /etc/conf.d/wireless-regdom >/dev/null
if command -v iw &>/dev/null; then
  sudo iw reg set IL
fi
