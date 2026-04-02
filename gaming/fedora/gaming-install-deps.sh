#!/usr/bin/env bash
set -e

# ================================
# INSTALAÇÃO AMBIENTE GAMER - FEDORA
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

# Pacotes Fedora
PACKAGES=(
    wine
    winetricks
    gamemode
    mangohud
    vulkan-tools
    mesa-vulkan-drivers
    mesa-demos
)

# Multilib (Steam/Wine)
MULTILIB_PACKAGES=(
    mesa-libGL.i686
    mesa-libGLU.i686
    mesa-vulkan-drivers.i686
)

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} INSTALAÇÃO DO AMBIENTE GAMER (FEDORA)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# Atualizar sistema
# =====================================
section "Atualizando sistema"

dnf upgrade -y

# =====================================
# RPM Fusion (ESSENCIAL)
# =====================================
section "Configurando RPM Fusion"

if dnf repolist | grep -q rpmfusion; then
    log_warn "RPM Fusion já configurado"
else
    log_info "Instalando RPM Fusion"
    dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    log_ok "RPM Fusion instalado"
fi

# =====================================
# Instalar pacotes principais
# =====================================
section "Instalando ferramentas"

for pkg in "${PACKAGES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        log_warn "$pkg já está instalado"
    else
        log_info "Instalando $pkg"
        dnf install -y "$pkg"
        log_ok "$pkg instalado"
    fi
done

# =====================================
# Instalar multilib
# =====================================
section "Configurando suporte 32-bit"

for pkg in "${MULTILIB_PACKAGES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        log_warn "$pkg já instalado"
    else
        log_info "Instalando $pkg"
        dnf install -y "$pkg"
        log_ok "$pkg instalado"
    fi
done

# =====================================
# Steam (Flatpak recomendado)
# =====================================
section "Instalando Steam (Flatpak)"

if ! command -v flatpak >/dev/null 2>&1; then
    log_info "Instalando Flatpak"
    dnf install -y flatpak
fi

if ! flatpak remote-list | grep -q flathub; then
    log_info "Adicionando Flathub"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

if flatpak list | grep -q com.valvesoftware.Steam; then
    log_warn "Steam já instalado via Flatpak"
else
    log_info "Instalando Steam"
    flatpak install -y flathub com.valvesoftware.Steam
    log_ok "Steam instalado"
fi

# =====================================
# Verificação final
# =====================================
section "Verificação final"

for pkg in "${PACKAGES[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        log_ok "$pkg"
    else
        echo -e "${RED}[FALHA]${NC} $pkg"
    fi
done

echo
log_ok "Ambiente gamer Fedora pronto"