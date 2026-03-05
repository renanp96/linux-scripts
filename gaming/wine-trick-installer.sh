#!/usr/bin/env bash
set -e

# ================================
# PREPARAÇÃO WINE PARA JOGOS
# ================================

# Auto-elevação
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Prefixo dedicado para jogos
export WINEPREFIX="$HOME/.wine-gaming"

# ================================
# Funções
# ================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} CONFIGURAÇÃO DO WINE PARA JOGOS${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. Arquitetura 32-bit
# =====================================
section "Ativando arquitetura i386"

if dpkg --print-foreign-architectures | grep -q i386; then
    log_warn "Arquitetura i386 já ativada"
else
    dpkg --add-architecture i386
    log_ok "Arquitetura i386 ativada"
fi

# =====================================
# 2. Atualizar repositórios
# =====================================
section "Atualizando repositórios"

apt update

# =====================================
# 3. Instalar Wine
# =====================================
section "Instalando Wine"

apt install -y \
    wine \
    wine32 \
    wine64 \
    winetricks

log_ok "Wine e Winetricks instalados"

# =====================================
# 4. Criar prefixo Wine limpo
# =====================================
section "Criando prefixo Wine"

if [ -d "$WINEPREFIX" ]; then
    log_warn "Prefixo já existe: $WINEPREFIX"
else
    mkdir -p "$WINEPREFIX"
    WINEPREFIX="$WINEPREFIX" wineboot --init
    log_ok "Prefixo criado em $WINEPREFIX"
fi

# =====================================
# 5. Instalar bibliotecas essenciais
# =====================================
section "Instalando bibliotecas de jogos"

log_info "Instalando dependências (pode demorar alguns minutos)"

sudo -u "$SUDO_USER" WINEPREFIX="$WINEPREFIX" winetricks -q \
    corefonts \
    vcrun2015 vcrun2017 vcrun2019 vcrun2022 \
    d3dx9 d3dx10 d3dx11 \
    dxvk \
    dotnet48 || log_warn "Algumas bibliotecas podem ter falhado"

# =====================================
# 6. Verificação final
# =====================================
section "Verificação"

if command -v wine >/dev/null 2>&1; then
    wine --version
    log_ok "Wine funcionando"
else
    echo -e "${RED}[FAIL] Wine não encontrado${NC}"
fi

echo
log_ok "Wine configurado com sucesso"
echo
echo "Prefixo utilizado:"
echo "  $WINEPREFIX"
echo
echo "Comandos úteis:"
echo "  winecfg"
echo "  winetricks"
echo "  WINEPREFIX=$WINEPREFIX wine <programa.exe>"