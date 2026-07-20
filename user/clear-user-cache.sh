#!/usr/bin/env bash

set -uo pipefail

# ===============================
# Cores
# ===============================
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

info() { echo -e "${BLUE}➜ $1${RESET}"; }
ok()   { echo -e "${GREEN}✔ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $1${RESET}"; }

echo
echo -e "${BLUE}=======================================${RESET}"
echo -e "${BLUE}   LIMPEZA DE CACHE (MODO SEGURO)     ${RESET}"
echo -e "${BLUE}=======================================${RESET}"
echo

# ===============================
# Checar processo rodando (com fallback pro pgrep do busybox,
# que não suporta a flag -x de correspondência exata)
# ===============================
process_running() {
    local name="$1"
    if pgrep -x "$name" >/dev/null 2>&1; then
        return 0
    fi
    pgrep "$name" >/dev/null 2>&1
}

# ===============================
# Fechar apps críticos
# ===============================
info "Verificando processos ativos..."

for proc in firefox chrome chromium code; do
    if process_running "$proc"; then
        warn "$proc está aberto (recomendado fechar antes)"
    fi
done

# ===============================
# Cache geral (com limite)
# ===============================
info "Limpando cache geral antigo (>3 dias)..."

if [[ -d "$HOME/.cache" ]]; then
    find "$HOME/.cache" -type f -atime +3 -delete 2>/dev/null
    ok "Cache antigo removido (seguro)"
else
    warn "~/.cache não encontrado"
fi

# ===============================
# GNOME / KDE / Cinnamon
# ===============================
info "Limpando caches de desktop..."

# Compartilhado (GTK/qualquer DE)
rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true
rm -rf "$HOME/.cache/mesa_shader_cache/"* 2>/dev/null || true

# Cinnamon
rm -rf "$HOME/.cache/cinnamon/"* 2>/dev/null || true

# KDE Plasma (o script original citava KDE no comentário, mas não
# limpava nada específico dele — corrigido aqui)
rm -rf "$HOME/.cache/plasma"*/ 2>/dev/null || true
rm -rf "$HOME/.cache/plasmashell/"* 2>/dev/null || true
rm -rf "$HOME/.cache/kioworker/"* 2>/dev/null || true
rm -f  "$HOME/.cache/icon-cache.kcache" 2>/dev/null || true

ok "Caches gráficos limpos"

# ===============================
# Flatpak
# ===============================
info "Limpando cache Flatpak..."

if command -v flatpak >/dev/null 2>&1; then
    flatpak uninstall --unused -y >/dev/null 2>&1 || true
    ok "Flatpak limpo"
else
    warn "Flatpak não instalado"
fi

# ===============================
# Navegadores (modo seguro)
# Detecta forma de instalação (nativo / Flatpak / Snap), já que isso
# muda onde o cache realmente fica — isso hoje varia mais por essa
# escolha do que pela distro em si (ex: Fedora recente e Ubuntu recente
# tendem a vir com Firefox via Flatpak/Snap, não mais pacote nativo)
# ===============================
info "Limpando cache de navegadores..."

# --- Firefox ---
FIREFOX_CACHE_DIRS=(
    "$HOME/.cache/mozilla/firefox"                                   # nativo
    "$HOME/.var/app/org.mozilla.firefox/cache/mozilla/firefox"        # Flatpak
    "$HOME/snap/firefox/common/.cache/mozilla/firefox"                # Snap
)
for base in "${FIREFOX_CACHE_DIRS[@]}"; do
    [ -d "$base" ] || continue
    find "$base" -type d -name "cache2" -exec sh -c 'rm -rf "$1"/*' _ {} \; 2>/dev/null || true
done

# --- Chrome / Chromium ---
# Cobri nativo e Flatpak com confiança; NÃO incluí o caminho do Snap do
# Chromium aqui porque o layout interno dele é menos padronizado e não
# tenho certeza suficiente do caminho exato para não arriscar apagar
# (ou simplesmente não achar) o lugar errado — se você usa a versão
# Snap, me diga o caminho real que eu adiciono.
CHROME_CACHE_DIRS=(
    "$HOME/.cache/google-chrome"                              # nativo
    "$HOME/.cache/chromium"                                    # nativo
    "$HOME/.var/app/com.google.Chrome/cache/google-chrome"     # Flatpak
    "$HOME/.var/app/org.chromium.Chromium/cache/chromium"      # Flatpak
)
for dir in "${CHROME_CACHE_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    rm -rf "${dir:?}/"* 2>/dev/null || true
done

ok "Caches de navegador limpos"

# ===============================
# Logs do usuário
# ===============================
info "Limpando logs antigos..."

find "$HOME/.local/share" -type f -name "*.log" -atime +7 -delete 2>/dev/null || true

ok "Logs antigos removidos"

# ===============================
# /tmp seguro
# ===============================
info "Limpando /tmp (arquivos antigos)..."

if command -v sudo >/dev/null 2>&1; then
    sudo find /tmp -type f -atime +3 -delete 2>/dev/null || true
    ok "/tmp limpo"
else
    warn "'sudo' não encontrado — limpeza de /tmp pulada"
fi

# ===============================
# Espaço liberado
# ===============================
info "Espaço em disco atual:"

df -h /

echo
echo -e "${GREEN}=======================================${RESET}"
echo -e "${GREEN}        LIMPEZA CONCLUÍDA              ${RESET}"
echo -e "${GREEN}=======================================${RESET}"
echo