#!/bin/bash
# Script para verificar status de conexão com a internet
# Autor: Renan P Andrade
# Data: 2026-05-17

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Hosts para teste de conectividade
PING_HOSTS=("8.8.8.8" "1.1.1.1" "9.9.9.9")
DNS_HOSTS=("google.com" "cloudflare.com")
SPEEDTEST_HOST="http://speedtest.tele2.net/1MB.test"

echo "=========================================="
echo "   Verificação de Conexão com a Internet  "
echo "=========================================="
echo ""

# ─────────────────────────────────────────────
# Função: verificar gateway local
# ─────────────────────────────────────────────
check_gateway() {
    echo -e "${BOLD}--- Gateway Local ---${NC}"
    GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
    if [ -z "$GATEWAY" ]; then
        echo -e "${RED}✗ Nenhum gateway encontrado${NC}"
        return 1
    fi
    echo -n "Gateway detectado ($GATEWAY)... "
    if ping -c 2 -W 2 "$GATEWAY" &>/dev/null; then
        echo -e "${GREEN}✓ Acessível${NC}"
    else
        echo -e "${RED}✗ Inacessível${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────
# Função: teste de ping para IPs externos
# ─────────────────────────────────────────────
check_ping() {
    echo -e "${BOLD}--- Conectividade Externa (Ping) ---${NC}"
    local success=0
    for host in "${PING_HOSTS[@]}"; do
        echo -n "Pingando $host... "
        if ping -c 3 -W 2 "$host" &>/dev/null; then
            RTT=$(ping -c 3 -W 2 "$host" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' 2>/dev/null)
            echo -e "${GREEN}✓ OK${NC} (avg ${RTT} ms)"
            success=1
        else
            echo -e "${RED}✗ Sem resposta${NC}"
        fi
    done
    echo ""
    return $((1 - success))
}

# ─────────────────────────────────────────────
# Função: resolução de DNS
# ─────────────────────────────────────────────
check_dns() {
    echo -e "${BOLD}--- Resolução de DNS ---${NC}"
    local success=0
    for host in "${DNS_HOSTS[@]}"; do
        echo -n "Resolvendo $host... "
        if nslookup "$host" &>/dev/null 2>&1; then
            IP=$(nslookup "$host" 2>/dev/null | awk '/^Address: / {print $2; exit}')
            echo -e "${GREEN}✓ OK${NC} ($IP)"
            success=1
        else
            echo -e "${RED}✗ Falha na resolução${NC}"
        fi
    done
    echo ""
    return $((1 - success))
}

# ─────────────────────────────────────────────
# Função: estimativa de velocidade de download
# ─────────────────────────────────────────────
check_speed() {
    echo -e "${BOLD}--- Estimativa de Velocidade ---${NC}"
    if ! command -v curl &>/dev/null; then
        echo -e "${YELLOW}curl não encontrado, pulando teste de velocidade${NC}"
        echo ""
        return
    fi
    echo -n "Baixando arquivo de teste (1MB)... "
    START=$(date +%s%N)
    if curl -s -o /dev/null --max-time 15 "$SPEEDTEST_HOST"; then
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        SPEED=$(echo "scale=2; 1024 / $ELAPSED * 1000 / 1024" | bc 2>/dev/null || echo "N/A")
        echo -e "${GREEN}✓ Concluído${NC}"
        echo -e "  Tempo: ${ELAPSED} ms | Velocidade estimada: ${CYAN}${SPEED} Mbps${NC}"
    else
        echo -e "${RED}✗ Falha no download de teste${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────
# Função: status da interface de rede
# ─────────────────────────────────────────────
check_interfaces() {
    echo -e "${BOLD}--- Interfaces de Rede Ativas ---${NC}"
    ip -br addr show | while read -r iface state addr; do
        if [ "$state" = "UP" ]; then
            echo -e "  ${GREEN}▲ $iface${NC} — $addr"
        elif [ "$state" = "DOWN" ]; then
            echo -e "  ${RED}▼ $iface${NC} — inativa"
        fi
    done
    echo ""
}

# ─────────────────────────────────────────────
# Execução
# ─────────────────────────────────────────────
check_interfaces
check_gateway
check_ping
PING_STATUS=$?
check_dns
DNS_STATUS=$?
check_speed

echo "=========================================="
echo "   Resumo Final                           "
echo "=========================================="
echo ""
echo -n "Conectividade externa: "
[ $PING_STATUS -eq 0 ] && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ Sem conexão${NC}"
echo -n "Resolução de DNS:      "
[ $DNS_STATUS -eq 0 ] && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ Falha${NC}"
echo ""
echo "Verificação concluída em: $(date '+%Y-%m-%d %H:%M:%S')"