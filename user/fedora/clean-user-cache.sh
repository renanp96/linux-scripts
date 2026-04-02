#!/usr/bin/env bash
set -e

# ===============================
# Cores
# ===============================
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

info() { echo -e "${BLUE}➜ $1${RESET}"; }
ok() { echo -e "${GREEN}✔ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $1${RESET}"; }

echo
echo -e "${BLUE}=======================================${RESET}"
echo -e "${BLUE}   LIMPEZA DE CACHE (MODO SEGURO)     ${RESET}"
echo -e "${BLUE}=======================================${RESET}"
echo

# ===============================
# Fechar apps críticos
# ===============================
info "Verificando processos ativos..."

for proc in firefox chrome chromium code; do
    if pgrep -x "$proc" >/dev/null; then
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

rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true
rm -rf "$HOME/.cache/mesa_shader_cache/"* 2>/dev/null || true
rm -rf "$HOME/.cache/cinnamon/"* 2>/dev/null || true

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
# ===============================
info "Limpando cache de navegadores..."

# Firefox
find "$HOME/.cache/mozilla/firefox/" -type d -name "cache2" -exec rm -rf {}/* \; 2>/dev/null || true

# Chrome / Chromium
rm -rf "$HOME/.cache/google-chrome/"* 2>/dev/null || true
rm -rf "$HOME/.cache/chromium/"* 2>/dev/null || true

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

sudo find /tmp -type f -atime +3 -delete 2>/dev/null || true

ok "/tmp limpo"

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