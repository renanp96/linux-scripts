#!/usr/bin/env bash

# ================================
# LIMPEZA STEAM / PROTON - FEDORA
# ================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detectar Steam (RPM ou Flatpak)
STEAM_NATIVE="$HOME/.steam/steam"
STEAM_FLATPAK="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"

if [ -d "$STEAM_NATIVE" ]; then
    STEAM="$STEAM_NATIVE"
    MODE="Native"
elif [ -d "$STEAM_FLATPAK" ]; then
    STEAM="$STEAM_FLATPAK"
    MODE="Flatpak"
else
    STEAM=""
fi

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
echo -e "${CYAN} LIMPEZA STEAM / PROTON (FEDORA)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# Verificar Steam
# =====================================
section "Detectando Steam"

if [ -z "$STEAM" ]; then
    log_warn "Steam não encontrado (nem Native nem Flatpak)"
    exit 1
else
    log_success "Steam detectado ($MODE)"
    echo "Caminho: $STEAM"
fi

# =====================================
# Espaço antes
# =====================================
section "Espaço antes da limpeza"

du -sh "$STEAM/steamapps" 2>/dev/null || log_warn "steamapps não encontrado"

# =====================================
# Fechar Steam (importante)
# =====================================
section "Verificando processos Steam"

if pgrep -x steam >/dev/null; then
    log_warn "Steam está aberto — fechando..."
    pkill steam
    sleep 3
    log_success "Steam encerrado"
else
    log_info "Steam já está fechado"
fi

# =====================================
# Shader Cache
# =====================================
section "Limpando Shader Cache"

if [ -d "$STEAM/steamapps/shadercache" ]; then
    rm -rf "$STEAM/steamapps/shadercache/"*
    log_success "Shader cache removido"
else
    log_warn "Shader cache não encontrado"
fi

# =====================================
# Downloads
# =====================================
section "Limpando downloads incompletos"

if [ -d "$STEAM/steamapps/downloading" ]; then
    rm -rf "$STEAM/steamapps/downloading/"*
    log_success "Downloads incompletos removidos"
else
    log_warn "Pasta downloading não encontrada"
fi

# =====================================
# Cache geral
# =====================================
section "Limpando cache geral"

if [ -d "$STEAM/appcache" ]; then
    rm -rf "$STEAM/appcache"
    log_success "Appcache removido"
else
    log_warn "Appcache não encontrado"
fi

# =====================================
# Logs antigos (extra útil)
# =====================================
section "Limpando logs"

if [ -d "$STEAM/logs" ]; then
    find "$STEAM/logs" -type f -name "*.log" -delete
    log_success "Logs removidos"
else
    log_warn "Logs não encontrados"
fi

# =====================================
# Compatdata (Proton)
# =====================================
section "Compatdata (Proton)"

echo -e "${YELLOW}Isso remove saves/mods/configs de jogos via Proton.${NC}"
read -p "Deseja limpar compatdata? (s/N): " confirm

if [[ "$confirm" =~ ^[sS]$ ]]; then
    rm -rf "$STEAM/steamapps/compatdata/"*
    log_success "Compatdata removido"
else
    log_warn "Compatdata preservado"
fi

# =====================================
# Espaço depois
# =====================================
section "Espaço após limpeza"

du -sh "$STEAM/steamapps" 2>/dev/null || log_warn "Erro ao calcular espaço"

echo
log_success "Limpeza concluída com sucesso"