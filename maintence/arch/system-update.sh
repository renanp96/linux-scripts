#!/usr/bin/env bash
set -e

# ================================
# ATUALIZAÇÃO DO SISTEMA - ARCH
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
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN}   ATUALIZAÇÃO DO SISTEMA (ARCH)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. Verificação de rede
# =====================================
section "Verificando conexão de rede"

if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "Conexão com internet OK"
else
    log_error "Sem conexão com internet"
    exit 1
fi

# =====================================
# 2. Sincronizar e atualizar sistema
# =====================================
section "Atualizando sistema (rolling release)"

sudo pacman -Syu --noconfirm

log_success "Sistema atualizado"

# =====================================
# 3. Limpeza de cache
# =====================================
section "Limpando cache de pacotes"

if command -v paccache >/dev/null 2>&1; then
    sudo paccache -r
    log_success "Cache limpo (mantidas versões recentes)"
else
    log_warn "paccache não encontrado (instale pacman-contrib)"
fi

# =====================================
# 4. Remover pacotes órfãos
# =====================================
section "Removendo pacotes órfãos"

ORPHANS=$(pacman -Qtdq || true)

if [ -z "$ORPHANS" ]; then
    log_success "Nenhum pacote órfão"
else
    echo "$ORPHANS"
    sudo pacman -Rns --noconfirm $ORPHANS
    log_success "Pacotes órfãos removidos"
fi

# =====================================
# 5. Verificação de falhas
# =====================================
section "Verificando falhas no sistema"

if journalctl -p 3 -xb | grep -q .; then
    log_warn "Erros recentes encontrados no sistema"
    echo "Use: journalctl -p 3 -xb"
else
    log_success "Nenhum erro crítico detectado"
fi

# =====================================
# 6. Verificar necessidade de reboot
# =====================================
section "Verificando necessidade de reinicialização"

if command -v checkupdates >/dev/null 2>&1; then
    if checkupdates | grep -qi "linux"; then
        log_warn "Kernel atualizado — reinicialização recomendada"
    else
        log_success "Sem necessidade de reboot imediato"
    fi
else
    log_warn "checkupdates não disponível (pacman-contrib)"
fi

echo
log_success "Sistema Arch atualizado com sucesso"