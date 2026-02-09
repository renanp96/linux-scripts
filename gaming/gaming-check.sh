#!/bin/bash

echo "== Gaming Environment Check =="

command -v steam >/dev/null && echo "Steam: OK" || echo "Steam: NAO INSTALADO"
command -v wine >/dev/null && echo "Wine: OK" || echo "Wine: NAO INSTALADO"
command -v winetricks >/dev/null && echo "Winetricks: OK" || echo "Winetricks: NAO INSTALADO"

echo
echo "GPU:"
lspci | grep -E "VGA|3D"

echo
echo "Vulkan:"
vulkaninfo >/dev/null 2>&1 && echo "Vulkan: OK" || echo "Vulkan: NAO DISPONIVEL"
