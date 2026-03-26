#!/usr/bin/env bash
set -e

# ================================
# ATUALIZAÇÃO DO SISTEMA
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
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
echo -e "${CYAN}   ATUALIZAÇÃO DO SISTEMA${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. Verificação de rede
# =====================================
section "Verificando conexão de rede"

if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "Conexão com internet detectada"
else
    log_error "Sem conexão com internet"
    exit 1
fi

# =====================================
# 2. Atualizar lista de pacotes
# =====================================
section "Atualizando lista de pacotes"

sudo apt update

# =====================================
# 3. Atualizar sistema
# =====================================
section "Atualizando pacotes instalados"

sudo apt upgrade -y

# =====================================
# 4. Remover pacotes desnecessários
# =====================================
section "Removendo pacotes antigos"

sudo apt autoremove -y
sudo apt autoclean

# =====================================
# 5. Verificar pacotes quebrados
# =====================================
section "Verificando pacotes quebrados"

BROKEN=$(dpkg -l | grep -E "^..r|^..U|^..iF")

if [ -z "$BROKEN" ]; then
    log_success "Nenhum pacote quebrado detectado"
else
    log_warn "Pacotes com problemas detectados"
    echo "$BROKEN"
fi

# =====================================
# 6. Verificar se reboot é necessário
# =====================================
section "Verificando necessidade de reinicialização"

if [ -f /var/run/reboot-required ]; then
    log_warn "Reinicialização do sistema é recomendada"
else
    log_success "Nenhuma reinicialização necessária"
fi

echo
log_success "Sistema atualizado com sucesso"