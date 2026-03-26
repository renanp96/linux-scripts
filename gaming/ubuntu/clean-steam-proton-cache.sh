#!/bin/bash

# ================================
# LIMPEZA STEAM / PROTON
# ================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STEAM="$HOME/.steam/steam"

# ================================
# Funções
# ================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} LIMPEZA DE CACHE STEAM / PROTON${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# Verificar Steam
# =====================================
section "Verificando instalação do Steam"

if [ ! -d "$STEAM" ]; then
    log_warn "Steam não encontrado em $STEAM"
    exit 1
else
    log_success "Steam detectado"
fi

# =====================================
# Espaço atual
# =====================================
section "Espaço usado antes da limpeza"

du -sh "$STEAM/steamapps" 2>/dev/null

# =====================================
# Limpeza shader cache
# =====================================
section "Limpando Shader Cache"

rm -rf "$STEAM/steamapps/shadercache/"* 2>/dev/null

log_success "Shader cache removido"

# =====================================
# Limpeza downloads
# =====================================
section "Limpando downloads incompletos"

rm -rf "$STEAM/steamapps/downloading/"* 2>/dev/null

log_success "Downloads incompletos removidos"

# =====================================
# Limpeza cache geral
# =====================================
section "Limpando cache do Steam"

rm -rf "$STEAM/appcache" 2>/dev/null

log_success "Cache do Steam removido"

# =====================================
# Compatdata (Proton)
# =====================================
section "Compatdata (prefixos Proton)"

echo -e "${YELLOW}Compatdata pode conter configurações ou mods.${NC}"
read -p "Deseja limpar compatdata? (s/N): " confirm

if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
    rm -rf "$STEAM/steamapps/compatdata/"* 2>/dev/null
    log_success "Compatdata removido"
else
    log_warn "Compatdata preservado"
fi

# =====================================
# Espaço final
# =====================================
section "Espaço usado após limpeza"

du -sh "$STEAM/steamapps" 2>/dev/null

echo
log_success "Limpeza concluída"