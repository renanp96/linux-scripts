#!/bin/bash

# Detecta tema ativo
THEME=$(gsettings get org.cinnamon.desktop.interface icon-theme | tr -d "'")

ICON_NAME="steam"
ICON_SIZE="256x256"
SOURCE="/usr/share/icons/hicolor/$ICON_SIZE/apps/$ICON_NAME.png"
DEST="/usr/share/icons/$THEME/$ICON_SIZE/apps"

echo "Tema ativo: $THEME"
echo "Verificando ícone $ICON_NAME..."

# Verifica se o ícone já existe
if [ -f "$DEST/$ICON_NAME.png" ]; then
    echo "Ícone já existe no tema."
else
    echo "Criando estrutura..."
    sudo mkdir -p "$DEST"

    echo "Copiando ícone..."
    sudo cp "$SOURCE" "$DEST/"
fi

echo "Atualizando cache do tema..."
sudo gtk-update-icon-cache -f "/usr/share/icons/$THEME"

echo "Limpando cache do usuário..."
rm -rf ~/.cache/icon-cache.kcache
rm -rf ~/.cache/gtk-*

echo "✔ Correção concluída."
echo "Reinicie a sessão se necessário."