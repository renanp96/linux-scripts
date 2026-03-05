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
echo -e "${BLUE}     LIMPEZA DE CACHE DO USUÁRIO       ${RESET}"
echo -e "${BLUE}=======================================${RESET}"
echo

# ===============================
# Cache geral
# ===============================
info "Limpando cache geral (~/.cache)..."

if [[ -d "$HOME/.cache" ]]; then
    rm -rf "$HOME/.cache/"*
    ok "Cache geral limpo"
else
    warn "Diretório ~/.cache não encontrado"
fi

# ===============================
# Cache Cinnamon
# ===============================
info "Limpando cache do Cinnamon..."

if [[ -d "$HOME/.cache/cinnamon" ]]; then
    rm -rf "$HOME/.cache/cinnamon/"*
    ok "Cache do Cinnamon limpo"
else
    warn "Cache do Cinnamon não encontrado"
fi

# ===============================
# Thumbnails
# ===============================
info "Limpando miniaturas..."

if [[ -d "$HOME/.cache/thumbnails" ]]; then
    rm -rf "$HOME/.cache/thumbnails/"*
    ok "Miniaturas removidas"
else
    warn "Nenhuma miniatura encontrada"
fi

# ===============================
# Cache navegadores
# ===============================
info "Limpando cache de navegadores..."

rm -rf "$HOME/.cache/mozilla/firefox/"*/cache2/* 2>/dev/null || true
rm -rf "$HOME/.cache/google-chrome/"* 2>/dev/null || true
rm -rf "$HOME/.cache/chromium/"* 2>/dev/null || true

ok "Cache de navegadores limpo"

# ===============================
# /tmp (arquivos antigos)
# ===============================
info "Limpando arquivos temporários antigos..."

sudo find /tmp -type f -atime +3 -delete 2>/dev/null || true

ok "Arquivos temporários antigos removidos"

echo
echo -e "${GREEN}=======================================${RESET}"
echo -e "${GREEN}        LIMPEZA CONCLUÍDA              ${RESET}"
echo -e "${GREEN}=======================================${RESET}"
echo