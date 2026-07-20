#!/usr/bin/env bash

set -uo pipefail

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
# Detecção de init e do gerenciador de rede ATIVO
#
# Diferente de escolha de pacotes (que segue a família da distro), o
# gerenciador de conexão e o resolvedor de DNS são escolha de configuração
# do usuário/admin — dá pra rodar NetworkManager no Debian, systemd-networkd
# no Fedora, ou nem ter nenhum dos dois num servidor mínimo. Por isso,
# detectamos o que está REALMENTE ativo em vez de assumir uma pilha fixa.
# ─────────────────────────────────────────────
HAS_SYSTEMD=false
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi
HAS_OPENRC=false
command -v rc-service >/dev/null 2>&1 && HAS_OPENRC=true

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

DNS_STACK="nenhum"
if $HAS_SYSTEMD && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    DNS_STACK="systemd-resolved"
    run_step "Reiniciando systemd-resolved" systemctl restart systemd-resolved
    run_step "Sincronizando cache (resolvectl flush-caches)" resolvectl flush-caches
elif $HAS_SYSTEMD && systemctl is-active --quiet nscd 2>/dev/null; then
    DNS_STACK="nscd"
    run_step "Limpando cache do nscd" nscd --invalidate=hosts
elif $HAS_OPENRC && [ -x /etc/init.d/nscd ] && rc-service nscd status 2>/dev/null | grep -qi started; then
    DNS_STACK="nscd"
    run_step "Limpando cache do nscd" nscd --invalidate=hosts
elif command -v resolvconf >/dev/null 2>&1; then
    # resolvconf/openresolv — comum em Debian sem systemd-resolved
    DNS_STACK="resolvconf"
    run_step "Atualizando resolvconf" resolvconf -u
else
    echo -e "${YELLOW}Nenhum serviço de cache de DNS conhecido (systemd-resolved/nscd/resolvconf) detectado — pulando${NC}"
fi

echo ""

# ─────────────────────────────────────────────
# 2. Cache ARP e tabela de rotas
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Cache ARP e Tabela de Rotas ---${NC}"

if command -v ip >/dev/null 2>&1; then
    echo -n "Limpando cache ARP... "
    ip neigh flush all &>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${YELLOW}⚠ Ignorado${NC}"
else
    echo -e "${YELLOW}'ip' (iproute2) não encontrado — cache ARP não pôde ser limpo${NC}"
fi

echo -n "Limpando cache de rotas do kernel... "
if [ -w /proc/sys/net/ipv4/route/flush ]; then
    echo 3 > /proc/sys/net/ipv4/route/flush 2>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${YELLOW}⚠ Ignorado${NC}"
else
    echo -e "${YELLOW}⚠ Não disponível neste kernel${NC}"
fi

echo ""

# ─────────────────────────────────────────────
# 3. Parâmetros de rede (sysctl)
# Nível de kernel — independe totalmente de distro/init
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Otimização de Parâmetros TCP/IP ---${NC}"

if ! command -v sysctl >/dev/null 2>&1; then
    echo -e "${YELLOW}'sysctl' não encontrado (pacote procps/procps-ng) — seção pulada${NC}"
else
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
    apply_sysctl "net.ipv4.tcp_congestion_control" "bbr"    "Algoritmo de congestionamento BBR (requer módulo tcp_bbr carregado)"
    apply_sysctl "net.core.default_qdisc"       "fq"        "Disciplina de fila padrão (fq)"
    apply_sysctl "net.ipv4.tcp_fin_timeout"     "15"        "Timeout FIN reduzido"
    apply_sysctl "net.ipv4.tcp_keepalive_time"  "300"       "Keepalive TCP"
    apply_sysctl "net.ipv4.tcp_tw_reuse"        "1"         "Reutilização de sockets TIME_WAIT"
fi

echo ""

# ─────────────────────────────────────────────
# 4. Reiniciar o gerenciador de conexão ATIVO
# (NetworkManager, systemd-networkd, dhcpcd, ou o serviço 'networking' do
# OpenRC — o que quer que esteja realmente rodando neste sistema)
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Gerenciador de Rede ---${NC}"

CONN_MGR=""
if $HAS_SYSTEMD; then
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        CONN_MGR="NetworkManager"
    elif systemctl is-active --quiet systemd-networkd 2>/dev/null; then
        CONN_MGR="systemd-networkd"
    elif systemctl is-active --quiet dhcpcd 2>/dev/null; then
        CONN_MGR="dhcpcd"
    elif systemctl is-active --quiet networking 2>/dev/null; then
        CONN_MGR="networking"   # ifupdown clássico no Debian
    fi
elif $HAS_OPENRC; then
    if rc-service NetworkManager status 2>/dev/null | grep -qi started; then
        CONN_MGR="NetworkManager"
    elif rc-service networking status 2>/dev/null | grep -qi started; then
        CONN_MGR="networking"
    elif rc-service dhcpcd status 2>/dev/null | grep -qi started; then
        CONN_MGR="dhcpcd"
    fi
fi

if [ -z "$CONN_MGR" ]; then
    echo -e "${YELLOW}Não foi possível identificar um gerenciador de conexão ativo${NC}"
    echo -e "${YELLOW}(NetworkManager/systemd-networkd/dhcpcd/networking) — reinício pulado${NC}"
else
    echo -n "Reiniciando $CONN_MGR... "
    RESTART_OK=false
    if $HAS_SYSTEMD; then
        systemctl restart "$CONN_MGR" && RESTART_OK=true
    else
        rc-service "$CONN_MGR" restart && RESTART_OK=true
    fi

    if $RESTART_OK; then
        echo -e "${GREEN}✓ OK${NC}"
        sleep 3
        echo -n "Verificando reconexão... "
        if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
            echo -e "${GREEN}✓ Internet disponível${NC}"
        else
            echo -e "${YELLOW}⚠ Internet indisponível após reconexão${NC}"
        fi
    else
        echo -e "${RED}✗ Falha ao reiniciar $CONN_MGR${NC}"
    fi
fi

echo ""

# ─────────────────────────────────────────────
# 5. Verificar e reparar permissões de resolv.conf
# (genérico — funciona igual em qualquer distro/init)
# ─────────────────────────────────────────────
echo -e "${BOLD}--- Arquivo resolv.conf ---${NC}"

RESOLV="/etc/resolv.conf"
echo -n "Verificando $RESOLV... "
if [ -L "$RESOLV" ]; then
    echo -e "${GREEN}✓ Link simbólico correto${NC} → $(readlink -f "$RESOLV")"
elif [ -f "$RESOLV" ]; then
    echo -e "${YELLOW}⚠ Arquivo estático (não é symlink)${NC}"
    echo "  Conteúdo atual:"
    sed 's/^/    /' "$RESOLV"
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
if [ "$DNS_STACK" = "systemd-resolved" ] && command -v resolvectl >/dev/null 2>&1; then
    resolvectl status 2>/dev/null | grep "DNS Servers" | head -3 | sed 's/^/  /'
elif [ -f "$RESOLV" ]; then
    grep -E "^nameserver" "$RESOLV" 2>/dev/null | sed 's/^/  /'
else
    echo "  Não foi possível determinar (sem resolvectl e sem /etc/resolv.conf legível)"
fi

echo ""
echo -n "Conectividade final: "
if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓ Internet OK${NC}"
else
    echo -e "${RED}✗ Sem internet${NC}"
fi

echo ""
echo "Limpeza e otimização concluídas em: $(date '+%Y-%m-%d %H:%M:%S')"