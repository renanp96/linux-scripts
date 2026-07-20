#!/usr/bin/env bash
# ==========================================
# Script para verificar status de conexão com a internet
# Autor: Renan P Andrade
# Multi-distro
# ==========================================
set -uo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Hosts para teste de conectividade
PING_HOSTS=("8.8.8.8" "1.1.1.1" "9.9.9.9")
DNS_HOSTS=("google.com" "cloudflare.com")
SPEEDTEST_HOST="http://speedtest.tele2.net/1MB.test"

# ================================
# Detecção de distro (só pra dar dicas de instalação corretas)
# ================================
DISTRO_ID="desconhecida"
DISTRO_FAMILY="unknown"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-desconhecida}"
    ID_LIKE="${ID_LIKE:-}"
fi
case "$DISTRO_ID $ID_LIKE" in
    *fedora*|*rhel*|*centos*|*rocky*|*almalinux*) DISTRO_FAMILY="rhel" ;;
    *debian*|*ubuntu*)                            DISTRO_FAMILY="debian" ;;
    *arch*|*manjaro*|*endeavouros*)               DISTRO_FAMILY="arch" ;;
    *suse*|*opensuse*)                            DISTRO_FAMILY="suse" ;;
    *alpine*)                                      DISTRO_FAMILY="alpine" ;;
    *)
        if command -v dnf >/dev/null 2>&1;      then DISTRO_FAMILY="rhel"
        elif command -v apt >/dev/null 2>&1;    then DISTRO_FAMILY="debian"
        elif command -v pacman >/dev/null 2>&1; then DISTRO_FAMILY="arch"
        elif command -v zypper >/dev/null 2>&1; then DISTRO_FAMILY="suse"
        elif command -v apk >/dev/null 2>&1;    then DISTRO_FAMILY="alpine"
        fi
        ;;
esac

pkg_name() {
    local key="$1"
    case "$DISTRO_FAMILY-$key" in
        rhel-iproute2)   echo "iproute" ;;   # nome do pacote é diferente aqui!
        debian-iproute2) echo "iproute2" ;;
        arch-iproute2)   echo "iproute2" ;;
        suse-iproute2)   echo "iproute2" ;;
        alpine-iproute2) echo "iproute2" ;;

        rhel-dns-tools)   echo "bind-utils" ;;
        debian-dns-tools) echo "dnsutils" ;;   # bind9-dnsutils em versões mais novas
        arch-dns-tools)   echo "bind" ;;
        suse-dns-tools)   echo "bind-utils" ;;
        alpine-dns-tools) echo "bind-tools" ;;

        *) echo "$key" ;;
    esac
}

pkg_install_hint() {
    local key="$1"
    local pkg
    pkg=$(pkg_name "$key")
    case "$DISTRO_FAMILY" in
        rhel)   echo "sudo dnf install $pkg" ;;
        debian) echo "sudo apt install $pkg" ;;
        arch)   echo "sudo pacman -S $pkg" ;;
        suse)   echo "sudo zypper install $pkg" ;;
        alpine) echo "sudo apk add $pkg" ;;
        *)      echo "instale '$pkg' com o gerenciador de pacotes da sua distro" ;;
    esac
}

echo "=========================================="
echo "   Verificação de Conexão com a Internet  "
echo "=========================================="
echo ""

# ─────────────────────────────────────────────
# Função: verificar gateway local
# ─────────────────────────────────────────────
check_gateway() {
    echo -e "${BOLD}--- Gateway Local ---${NC}"
    if ! command -v ip >/dev/null 2>&1; then
        echo -e "${YELLOW}'ip' (iproute2) não encontrado ($(pkg_install_hint iproute2)) — pulando${NC}"
        echo ""
        return
    fi
    GATEWAY=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
    if [ -z "$GATEWAY" ]; then
        echo -e "${RED}✗ Nenhum gateway encontrado${NC}"
        echo ""
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
            # A linha de resumo "rtt min/avg/max/mdev" é do iputils (padrão na
            # maioria das distros). O ping do busybox (comum em imagens mínimas
            # Alpine) não imprime essa linha — nesse caso só não mostramos o RTT.
            RTT=$(ping -c 3 -W 2 "$host" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' 2>/dev/null)
            if [ -n "$RTT" ]; then
                echo -e "${GREEN}✓ OK${NC} (avg ${RTT} ms)"
            else
                echo -e "${GREEN}✓ OK${NC}"
            fi
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
# Tenta nslookup -> dig -> getent, na ordem, conforme disponibilidade —
# esses utilitários vêm de pacotes diferentes (e às vezes nem vêm por
# padrão) dependendo da distro, então não dá pra depender de só um.
# ─────────────────────────────────────────────
resolve_host() {
    local host="$1" ip=""
    if command -v nslookup >/dev/null 2>&1; then
        # Pula a(s) linha(s) do próprio servidor DNS e pega o Address
        # que vem DEPOIS da linha "Name:" (resposta real, não o resolver)
        ip=$(nslookup "$host" 2>/dev/null | awk '/^Name:/{f=1} f && /^Address: /{print $2; exit}')
    fi
    if [ -z "$ip" ] && command -v dig >/dev/null 2>&1; then
        ip=$(dig +short "$host" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    fi
    if [ -z "$ip" ] && command -v getent >/dev/null 2>&1; then
        ip=$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1; exit}')
        [ -z "$ip" ] && ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1; exit}')
    fi
    echo "$ip"
}

check_dns() {
    echo -e "${BOLD}--- Resolução de DNS ---${NC}"
    if ! command -v nslookup >/dev/null 2>&1 && ! command -v dig >/dev/null 2>&1 && ! command -v getent >/dev/null 2>&1; then
        echo -e "${YELLOW}Nenhuma ferramenta de resolução DNS encontrada ($(pkg_install_hint dns-tools)) — pulando${NC}"
        echo ""
        return 1
    fi
    local success=0
    for host in "${DNS_HOSTS[@]}"; do
        echo -n "Resolvendo $host... "
        IP=$(resolve_host "$host")
        if [ -n "$IP" ]; then
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
        echo -e "${YELLOW}curl não encontrado ($(pkg_install_hint curl)), pulando teste de velocidade${NC}"
        echo ""
        return
    fi
    echo -n "Baixando arquivo de teste (1MB)... "
    START=$(date +%s%N)
    if curl -s -o /dev/null --max-time 15 "$SPEEDTEST_HOST"; then
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        # Cálculo feito com awk em vez de 'bc' — awk já vem com o sistema em
        # praticamente qualquer distro, evitando mais uma dependência opcional.
        if [ "$ELAPSED" -gt 0 ]; then
            SPEED=$(awk -v e="$ELAPSED" 'BEGIN{printf "%.2f", (1024/e*1000/1024)}')
        else
            SPEED="N/A"
        fi
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
    if ! command -v ip >/dev/null 2>&1; then
        echo -e "${YELLOW}'ip' (iproute2) não encontrado ($(pkg_install_hint iproute2)) — pulando${NC}"
        echo ""
        return
    fi

    if ip -br addr show >/dev/null 2>&1; then
        # iproute2 "de verdade" — suporta -br (resumo tabular)
        ip -br addr show | while read -r iface state addr _; do
            if [ "$state" = "UP" ]; then
                echo -e "  ${GREEN}▲ $iface${NC} — ${addr:-sem IP}"
            elif [ "$state" = "DOWN" ]; then
                echo -e "  ${RED}▼ $iface${NC} — inativa"
            fi
        done
    else
        # Fallback para o applet 'ip' do busybox (comum em imagens mínimas
        # Alpine), que não suporta a flag -br
        log_iface=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^[0-9]+:\ ([^:@]+) ]]; then
                log_iface="${BASH_REMATCH[1]}"
                if echo "$line" | grep -q "state UP\|,UP,"; then
                    echo -e "  ${GREEN}▲ $log_iface${NC}"
                elif echo "$line" | grep -q "state DOWN"; then
                    echo -e "  ${RED}▼ $log_iface${NC} — inativa"
                fi
            fi
        done < <(ip addr show 2>/dev/null)
    fi
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