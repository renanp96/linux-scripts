#!/usr/bin/env bash
set -uo pipefail

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
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

# ================================
# 0. Nome da distro (só pra exibição —
# a limpeza em si não depende disso)
# ================================
DISTRO_NAME="Linux"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-Linux}"
fi

# ================================
# 1. Detectar instalação do Steam
# ================================
# A estrutura interna (~/.steam/steam -> .../Steam com steamapps, shadercache
# etc.) é definida pelo próprio instalador da Valve e é praticamente idêntica
# em qualquer distro. O que muda entre distros é o MÉTODO de instalação:
# pacote nativo (.rpm/.deb/pacman/AUR), Flatpak, ou Snap (comum no Ubuntu).
STEAM_NATIVE_SYMLINK="$HOME/.steam/steam"
STEAM_NATIVE_DIRECT="$HOME/.local/share/Steam"
STEAM_FLATPAK="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
STEAM_SNAP="$HOME/snap/steam/common/.local/share/Steam"

STEAM=""
MODE=""

if [ -d "$STEAM_NATIVE_SYMLINK" ]; then
    STEAM="$STEAM_NATIVE_SYMLINK"
    MODE="Nativo"
elif [ -d "$STEAM_NATIVE_DIRECT" ]; then
    STEAM="$STEAM_NATIVE_DIRECT"
    MODE="Nativo (sem symlink ~/.steam/steam ainda)"
elif [ -d "$STEAM_FLATPAK" ]; then
    STEAM="$STEAM_FLATPAK"
    MODE="Flatpak"
elif [ -d "$STEAM_SNAP" ]; then
    STEAM="$STEAM_SNAP"
    MODE="Snap"
fi

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} LIMPEZA STEAM / PROTON ($DISTRO_NAME)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# Verificar Steam
# =====================================
section "Detectando Steam"

if [ -z "$STEAM" ]; then
    log_warn "Steam não encontrado (Nativo, Flatpak ou Snap)"
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

if command -v pgrep >/dev/null 2>&1 && command -v pkill >/dev/null 2>&1; then
    if pgrep -x steam >/dev/null 2>&1; then
        log_warn "Steam está aberto — fechando..."
        pkill -x steam
        sleep 3
        log_success "Steam encerrado"
    else
        log_info "Steam já está fechado"
    fi
else
    # pgrep/pkill (pacote procps) podem faltar em instalações mínimas.
    log_warn "'pgrep'/'pkill' não encontrados — não foi possível checar/fechar o Steam automaticamente"
    log_warn "Feche o Steam manualmente antes de continuar, se ele estiver aberto"
    read -r -p "Pressione Enter para continuar mesmo assim, ou Ctrl+C para cancelar... "
fi

# =====================================
# Shader Cache
# =====================================
section "Limpando Shader Cache"

if [ -d "$STEAM/steamapps/shadercache" ]; then
    rm -rf "${STEAM:?}/steamapps/shadercache/"*
    log_success "Shader cache removido"
else
    log_warn "Shader cache não encontrado"
fi

# =====================================
# Downloads
# =====================================
section "Limpando downloads incompletos"

if [ -d "$STEAM/steamapps/downloading" ]; then
    rm -rf "${STEAM:?}/steamapps/downloading/"*
    log_success "Downloads incompletos removidos"
else
    log_warn "Pasta downloading não encontrada"
fi

# =====================================
# Cache geral
# =====================================
section "Limpando cache geral"

if [ -d "$STEAM/appcache" ]; then
    rm -rf "${STEAM:?}/appcache"
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
read -r -p "Deseja limpar compatdata? (s/N): " confirm

if [[ "$confirm" =~ ^[sS]$ ]]; then
    if [ -d "$STEAM/steamapps/compatdata" ]; then
        rm -rf "${STEAM:?}/steamapps/compatdata/"*
        log_success "Compatdata removido"
    else
        log_warn "Compatdata não encontrado"
    fi
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