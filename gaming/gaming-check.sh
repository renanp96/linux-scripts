#!/bin/bash

# ================================
# GAMING ENVIRONMENT CHECK
# ================================

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
echo -e "${CYAN}   GAMING ENVIRONMENT CHECK${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. Ferramentas básicas
# =====================================
section "Ferramentas de jogo"

if command -v steam >/dev/null 2>&1; then
    log_ok "Steam instalado"
else
    log_warn "Steam não instalado"
fi

if command -v wine >/dev/null 2>&1; then
    log_ok "Wine instalado"
else
    log_warn "Wine não instalado"
fi

if command -v winetricks >/dev/null 2>&1; then
    log_ok "Winetricks instalado"
else
    log_warn "Winetricks não instalado"
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
# 3. Driver NVIDIA (se existir)
# =====================================
section "Driver NVIDIA"

if command -v nvidia-smi >/dev/null 2>&1; then
    log_ok "Driver NVIDIA ativo"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    log_warn "Driver NVIDIA não detectado"
fi

# =====================================
# 4. OpenGL
# =====================================
section "OpenGL"

if command -v glxinfo >/dev/null 2>&1; then
    glxinfo | grep "OpenGL renderer"
else
    log_warn "mesa-utils não instalado (glxinfo)"
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
fi

echo
echo -e "${GREEN}Verificação de ambiente gamer concluída.${NC}"