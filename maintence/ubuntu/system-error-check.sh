#!/bin/bash

# ================================
# DIAGNÓSTICO RÁPIDO DO SISTEMA
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
echo -e "${CYAN}   DIAGNÓSTICO RÁPIDO DO SISTEMA${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. Espaço em disco
# =====================================
section "Espaço em disco (>=80% é alerta)"

df -h -x tmpfs -x devtmpfs | awk 'NR==1 || $5+0 >= 80'

# =====================================
# 2. Memória
# =====================================
section "Memória"

free -h

# =====================================
# 3. CPU / Load
# =====================================
section "CPU / Load"

uptime

# =====================================
# 4. Temperatura
# =====================================
section "Temperatura"

if command -v sensors >/dev/null 2>&1; then
    sensors
else
    log_warn "lm-sensors não instalado"
fi

# =====================================
# 5. Serviços com falha
# =====================================
section "Serviços com falha"

FAILED=$(systemctl --failed --no-pager)

if echo "$FAILED" | grep -q "0 loaded units listed"; then
    log_success "Nenhum serviço falhou"
else
    echo "$FAILED"
fi

# =====================================
# 6. Erros críticos do boot atual
# =====================================
section "Erros críticos do boot atual"

journalctl -p 3 -b --no-pager | tail -20 || log_success "Nenhum erro crítico"

# =====================================
# 7. Erros do boot anterior
# =====================================
section "Erros do boot anterior"

journalctl -p 3 -b -1 --no-pager | tail -20 || log_warn "Sem logs persistentes"

# =====================================
# 8. Pacotes quebrados
# =====================================
section "Pacotes quebrados"

BROKEN=$(dpkg -l | grep -E "^..r|^..U|^..iF")

if [ -z "$BROKEN" ]; then
    log_success "Nenhum pacote quebrado"
else
    echo "$BROKEN"
fi

# =====================================
# 9. Docker
# =====================================
section "Docker"

if command -v docker >/dev/null 2>&1; then
    docker ps --format "  - {{.Names}} ({{.Status}})" 2>/dev/null
else
    log_warn "Docker não instalado"
fi

# =====================================
# 10. GPU NVIDIA
# =====================================
section "GPU NVIDIA"

if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
else
    log_warn "Driver NVIDIA não carregado"
fi

# =====================================
# 11. Áudio
# =====================================
section "Stack de áudio"

if command -v pactl >/dev/null 2>&1; then
    pactl info | grep -E "Server Name|Default Sink"
else
    log_warn "Audio stack não encontrado"
fi

echo
log_success "Diagnóstico concluído"