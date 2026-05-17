#!/bin/bash
# Script para limpar cache de conexão e otimizar rede
# Autor: Renan P Andrade
# Data: 2026-05-17

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo "=========================================="
echo "   Limpeza de Cache e Otimização de Rede  "
echo "=========================================="
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Este script precisa ser executado como root (sudo)${NC}"
    exit 1
fi

# ─────────────────────────────────────────────
# Função: executar ação e reportar resultado
# ─────────────────────────────────────────────
run_step() {
    local description="$1"
    shift
    echo -n "$description... "
    if "$@" &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${YELLOW}⚠ Ignorado ou não aplicável${NC}"
    fi
}

# ─────────────────────────────────────────────
# 1. Cache DNS
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Cache DNS ---${NC}"

run_step "Reiniciando systemd-resolved" systemctl restart systemd-resolved
run_step "Limpando cache do nscd (se ativo)" bash -c "systemctl is-active --quiet nscd && nscd --invalidate=hosts"
run_step "Sincronizando resolv.conf" resolvectl flush-caches

echo ""

# ─────────────────────────────────────────────
# 2. Cache ARP e tabela de rotas
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Cache ARP e Tabela de Rotas ---${NC}"

echo -n "Limpando cache ARP... "
ip neigh flush all &>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${YELLOW}⚠ Ignorado${NC}"

echo -n "Limpando cache de rotas do kernel... "
echo 3 > /proc/sys/net/ipv4/route/flush 2>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${YELLOW}⚠ Ignorado${NC}"

echo ""

# ─────────────────────────────────────────────
# 3. Parâmetros de rede (sysctl)
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Otimização de Parâmetros TCP/IP ---${NC}"

apply_sysctl() {
    local param="$1"
    local value="$2"
    local desc="$3"
    echo -n "  $desc... "
    if sysctl -w "${param}=${value}" &>/dev/null; then
        echo -e "${GREEN}✓ OK${NC} (${param}=${value})"
    else
        echo -e "${YELLOW}⚠ Ignorado${NC}"
    fi
}

apply_sysctl "net.core.rmem_max"            "16777216"  "Buffer de recepção máximo"
apply_sysctl "net.core.wmem_max"            "16777216"  "Buffer de envio máximo"
apply_sysctl "net.ipv4.tcp_rmem"            "4096 87380 16777216" "Buffer TCP de recepção"
apply_sysctl "net.ipv4.tcp_wmem"            "4096 65536 16777216" "Buffer TCP de envio"
apply_sysctl "net.ipv4.tcp_fastopen"        "3"         "TCP Fast Open (cliente + servidor)"
apply_sysctl "net.ipv4.tcp_congestion_control" "bbr"    "Algoritmo de congestionamento BBR"
apply_sysctl "net.core.default_qdisc"       "fq"        "Disciplina de fila padrão (fq)"
apply_sysctl "net.ipv4.tcp_fin_timeout"     "15"        "Timeout FIN reduzido"
apply_sysctl "net.ipv4.tcp_keepalive_time"  "300"       "Keepalive TCP"
apply_sysctl "net.ipv4.tcp_tw_reuse"        "1"         "Reutilização de sockets TIME_WAIT"

echo ""

# ─────────────────────────────────────────────
# 4. Reiniciar NetworkManager
# ─────────────────────────────────────────────
echo -e "${BOLD}--- NetworkManager ---${NC}"

echo -n "Reiniciando NetworkManager... "
if systemctl restart NetworkManager; then
    echo -e "${GREEN}✓ OK${NC}"
    sleep 3
    echo -n "Verificando reconexão... "
    if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "${GREEN}✓ Internet disponível${NC}"
    else
        echo -e "${YELLOW}⚠ Internet indisponível após reconexão${NC}"
    fi
else
    echo -e "${RED}✗ Falha ao reiniciar NetworkManager${NC}"
fi

echo ""

# ─────────────────────────────────────────────
# 5. Verificar e reparar permissões de resolv.conf
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Arquivo resolv.conf ---${NC}"

RESOLV="/etc/resolv.conf"
echo -n "Verificando $RESOLV... "
if [ -L "$RESOLV" ]; then
    echo -e "${GREEN}✓ Link simbólico correto${NC} → $(readlink -f "$RESOLV")"
elif [ -f "$RESOLV" ]; then
    echo -e "${YELLOW}⚠ Arquivo estático (não é symlink)${NC}"
    echo "  Conteúdo atual:"
    cat "$RESOLV" | sed 's/^/    /'
else
    echo -e "${RED}✗ Arquivo não encontrado${NC}"
fi

echo ""

# ─────────────────────────────────────────────
# Resumo
# ─────────────────────────────────────────────
echo "=========================================="
echo "   Resumo                                 "
echo "=========================================="
echo ""
echo -e "DNS atual configurado:"
resolvectl status 2>/dev/null | grep "DNS Servers" | head -3 | sed 's/^/  /'

echo ""
echo -n "Conectividade final: "
if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓ Internet OK${NC}"
else
    echo -e "${RED}✗ Sem internet${NC}"
fi

echo ""
echo "Limpeza e otimização concluídas em: $(date '+%Y-%m-%d %H:%M:%S')"