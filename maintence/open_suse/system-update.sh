#!/usr/bin/env bash
set -e

# ================================
# ATUALIZAÇÃO DO SISTEMA - openSUSE
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
echo -e "${CYAN}   ATUALIZAÇÃO DO SISTEMA (openSUSE)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# Detectar versão
# =====================================
if grep -qi "tumbleweed" /etc/os-release; then
    DISTRO_TYPE="tumbleweed"
else
    DISTRO_TYPE="leap"
fi

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
# 2. Atualizar repositórios
# =====================================
section "Atualizando repositórios"

sudo zypper refresh

# =====================================
# 3. Atualização do sistema
# =====================================
section "Atualizando sistema"

if [ "$DISTRO_TYPE" = "tumbleweed" ]; then
    log_info "Sistema rolling release detectado (Tumbleweed)"
    sudo zypper dup -y
else
    log_info "Sistema estável detectado (Leap)"
    sudo zypper update -y
fi

log_success "Sistema atualizado"

# =====================================
# 4. Remover pacotes desnecessários
# =====================================
section "Removendo dependências não utilizadas"

sudo zypper packages --unneeded | awk 'NR>2 {print $5}' | xargs -r sudo zypper remove -y

log_success "Pacotes desnecessários removidos"

# =====================================
# 5. Limpeza de cache
# =====================================
section "Limpando cache"

sudo zypper clean --all

log_success "Cache limpo"

# =====================================
# 6. Verificação de problemas
# =====================================
section "Verificando inconsistências"

if sudo zypper verify; then
    log_success "Sistema íntegro"
else
    log_warn "Problemas encontrados (verifique acima)"
fi

# =====================================
# 7. Verificar reboot
# =====================================
section "Verificando necessidade de reboot"

if needs-rebooting >/dev/null 2>&1; then
    log_warn "Reinicialização recomendada"
else
    log_success "Sem necessidade de reboot"
fi

echo
log_success "Sistema openSUSE atualizado com sucesso"