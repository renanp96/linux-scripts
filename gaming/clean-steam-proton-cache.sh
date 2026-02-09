#!/bin/bash

STEAM="$HOME/.steam/steam"

echo "=== Limpeza de cache Steam & Proton ==="

# Proton (normalmente exige sudo)
echo "Limpando cache do Proton..."
sudo rm -rf "$STEAM/steamapps/shadercache/"*
sudo rm -rf "$STEAM/steamapps/compatdata/"*

# Steam (cache do usuário, sem sudo)
echo "Limpando cache do Steam..."
rm -rf "$STEAM/appcache"
rm -rf "$STEAM/steamapps/downloading/"*

echo "=== Limpeza concluída com sucesso ==="
