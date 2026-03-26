#!/usr/bin/env bash
set -e

# ================================
# INSTALAÇÃO AMBIENTE GAMER
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

# Pacotes
PACKAGES=(
wine
winetricks
gamemode
mangohud
vulkan-tools
mesa-vulkan-drivers
)

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} INSTALAÇÃO DO AMBIENTE GAMER${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# Atualizar repositórios
# =====================================
section "Atualizando repositórios"

apt update

# =====================================
# Instalar pacotes
# =====================================
section "Instalando ferramentas"

for pkg in "${PACKAGES[@]}"; do

    if dpkg -s "$pkg" >/dev/null 2>&1; then
        log_warn "$pkg já está instalado"
    else
        log_info "Instalando $pkg"
        apt install -y "$pkg"
        log_ok "$pkg instalado"
    fi

done

# =====================================
# Verificação final
# =====================================
section "Verificação final"

for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        log_ok "$pkg"
    else
        echo -e "${RED}[FALHA]${NC} $pkg"
    fi
done

echo
log_ok "Ambiente gamer preparado com sucesso"