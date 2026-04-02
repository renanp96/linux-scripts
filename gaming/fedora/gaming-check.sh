#!/bin/bash

# ================================
# GAMING ENVIRONMENT CHECK - FEDORA
# ================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================================
# Funções
# ================================
log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} GAMING ENVIRONMENT CHECK (FEDORA)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. Ferramentas básicas
# =====================================
section "Ferramentas de jogo"

# Steam (RPM ou Flatpak)
if command -v steam >/dev/null 2>&1 || flatpak list | grep -q com.valvesoftware.Steam; then
    log_ok "Steam instalado"
else
    log_warn "Steam não instalado (dnf ou flatpak)"
fi

# Wine
if command -v wine >/dev/null 2>&1; then
    log_ok "Wine instalado"
else
    log_warn "Wine não instalado"
fi

# Winetricks
if command -v winetricks >/dev/null 2>&1; then
    log_ok "Winetricks instalado"
else
    log_warn "Winetricks não instalado"
fi

# Lutris
if command -v lutris >/dev/null 2>&1; then
    log_ok "Lutris instalado"
else
    log_warn "Lutris não instalado"
fi

# =====================================
# 2. GPU
# =====================================
section "GPU detectada"

GPU=$(lspci | grep -E "VGA|3D")

if [ -n "$GPU" ]; then
    echo "$GPU"
else
    log_fail "Nenhuma GPU detectada"
fi

# =====================================
# 3. Drivers NVIDIA (RPM Fusion)
# =====================================
section "Driver NVIDIA"

if command -v nvidia-smi >/dev/null 2>&1; then
    log_ok "Driver NVIDIA ativo"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    log_warn "Driver NVIDIA não detectado"
    echo "Dica: sudo dnf install akmod-nvidia (RPM Fusion)"
fi

# =====================================
# 4. OpenGL (Mesa)
# =====================================
section "OpenGL"

if command -v glxinfo >/dev/null 2>&1; then
    glxinfo | grep "OpenGL renderer"
else
    log_warn "mesa-demos não instalado"
    echo "Instale com: sudo dnf install mesa-demos"
fi

# =====================================
# 5. Vulkan
# =====================================
section "Vulkan"

if command -v vulkaninfo >/dev/null 2>&1; then
    if vulkaninfo >/dev/null 2>&1; then
        log_ok "Vulkan funcionando"
    else
        log_fail "Vulkan instalado mas com erro"
    fi
else
    log_warn "Vulkan não instalado"
    echo "Instale com: sudo dnf install vulkan-tools"
fi

# =====================================
# 6. Bibliotecas 32-bit (importante pro Steam)
# =====================================
section "Suporte 32-bit (multilib)"

if rpm -qa | grep -q mesa-libGL.i686; then
    log_ok "Bibliotecas 32-bit instaladas"
else
    log_warn "Faltando libs 32-bit"
    echo "Instale com:"
    echo "sudo dnf install mesa-libGL.i686 mesa-libGLU.i686"
fi

# =====================================
# 7. RPM Fusion (essencial no Fedora)
# =====================================
section "Repositórios RPM Fusion"

if dnf repolist | grep -q rpmfusion; then
    log_ok "RPM Fusion configurado"
else
    log_warn "RPM Fusion não configurado"
    echo "Instale com:"
    echo "sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm"
    echo "sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm"
fi

echo
echo -e "${GREEN}Verificação gamer no Fedora concluída.${NC}"