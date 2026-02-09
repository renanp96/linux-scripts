#!/bin/bash
exec sudo bash -c '

apt update
apt install -y \
  wine \
  winetricks \
  gamemode \
  mangohud \
  vulkan-tools \
  mesa-vulkan-drivers
'
