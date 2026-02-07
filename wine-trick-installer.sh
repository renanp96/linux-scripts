#!/usr/bin/env bash
set -e

echo "🔧 Preparando Wine para jogos no Linux Mint..."

# Ativar arquitetura 32-bit (obrigatório)
echo "➡️ Ativando arquitetura i386..."
sudo dpkg --add-architecture i386

# Atualizar sistema
echo "🔄 Atualizando repositórios..."
sudo apt update

# Instalar Wine (estável) e dependências comuns
echo "🍷 Instalando Wine..."
sudo apt install -y wine wine32 wine64

# Instalar Winetricks
echo "🎮 Instalando Winetricks..."
sudo apt install -y winetricks

# Inicializar Wine (cria prefixo padrão limpo)
echo "🧪 Inicializando Wine..."
wineboot --init

# Instalar bibliotecas comuns para jogos
echo "📦 Instalando bibliotecas essenciais para jogos..."
winetricks -q \
  corefonts \
  vcrun2015 vcrun2017 vcrun2019 vcrun2022 \
  d3dx9 d3dx10 d3dx11 d3dx12 \
  dxvk \
  dotnet48

echo "✅ Wine configurado com sucesso!"
echo "➡️ Para abrir a configuração do Wine: winecfg"
echo "➡️ Para gerenciar componentes: winetricks"
