#!/bin/bash

echo "== Limpeza de cache e arquivos temporarios do usuario =="

# Cache geral
echo "Limpando ~/.cache..."
sudo rm -rf ~/.cache/*

# Cache do Cinnamon
echo "Limpando cache do Cinnamon..."
sudo rm -rf ~/.cache/cinnamon/*

# Thumbnails
echo "Limpando miniaturas..."
sudo rm -rf ~/.cache/thumbnails/*

# Cache de navegadores
echo "Limpando cache de navegadores..."

sudo rm -rf ~/.cache/mozilla/firefox/*/cache2/* 2>/dev/null
sudo rm -rf ~/.cache/google-chrome/* 2>/dev/null
sudo rm -rf ~/.cache/chromium/* 2>/dev/null

# Arquivos temporarios
echo "Limpando arquivos temporarios..."
sudo rm -rf /tmp/*

echo
echo "== Limpeza concluida =="
