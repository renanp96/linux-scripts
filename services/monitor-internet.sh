#!/usr/bin/env bash
# ==========================================
# Script para monitorar conexão com a internet em background
# Registra quedas de conexão e quedas bruscas de velocidade em log
# Autor: Renan P Andrade
# Multi-distro
#
# Uso:
#   ./monitor-internet.sh start    — inicia monitoramento em background
#   ./monitor-internet.sh stop     — para o monitoramento
#   ./monitor-internet.sh status   — exibe status e últimas entradas do log
#   ./monitor-internet.sh log      — exibe o log completo
# ==========================================
set -uo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────
# Configurações
# ─────────────────────────────────────────────
LOG_FILE="${HOME}/.local/share/net-monitor/internet-monitor.log"
PID_FILE="${HOME}/.local/share/net-monitor/internet-monitor.pid"
PING_HOST="8.8.8.8"
CHECK_INTERVAL=10          # segundos entre cada verificação
SPEED_TEST_URL="http://speedtest.tele2.net/1MB.test"
SPEED_DROP_THRESHOLD=5     # Mbps — abaixo disso registra como queda de velocidade
SPEED_CHECK_INTERVAL=60    # segundos entre cada teste de velocidade (mais pesado)

mkdir -p "$(dirname "$LOG_FILE")"

# ─────────────────────────────────────────────
# Detecção leve de distro — só usada pra dar a dica de instalação certa
# caso falte alguma ferramenta (aqui, só o curl é opcional de verdade)
# ─────────────────────────────────────────────
DISTRO_FAMILY="unknown"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    ID_LIKE=""
    source /etc/os-release
fi
case "${ID:-} ${ID_LIKE:-}" in
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

pkg_install_hint() {
    local pkg="$1"
    case "$DISTRO_FAMILY" in
        rhel)   echo "sudo dnf install $pkg" ;;
        debian) echo "sudo apt install $pkg" ;;
        arch)   echo "sudo pacman -S $pkg" ;;
        suse)   echo "sudo zypper install $pkg" ;;
        alpine) echo "sudo apk add $pkg" ;;
        *)      echo "instale '$pkg' com o gerenciador de pacotes da sua distro" ;;
    esac
}

# ─────────────────────────────────────────────
# Função: timestamp
# ─────────────────────────────────────────────
ts() {
    date '+%Y-%m-%d %H:%M:%S'
}

# ─────────────────────────────────────────────
# Função: gravar no log
# ─────────────────────────────────────────────
log_event() {
    local level="$1"
    local message="$2"
    echo "[$(ts)] [$level] $message" >> "$LOG_FILE"
}

# ─────────────────────────────────────────────
# Função: teste de ping
# ─────────────────────────────────────────────
check_ping() {
    ping -c 3 -W 3 "$PING_HOST" &>/dev/null
    return $?
}

# ─────────────────────────────────────────────
# Função: estimativa de velocidade de download
# (cálculo feito com awk em vez de 'bc' — awk é praticamente garantido
# em qualquer distro, enquanto 'bc' costuma ser um pacote opcional à parte)
# ─────────────────────────────────────────────
check_speed() {
    if ! command -v curl &>/dev/null; then
        echo "N/A"
        return
    fi
    START=$(date +%s%N)
    if curl -s -o /dev/null --max-time 20 "$SPEED_TEST_URL" 2>/dev/null; then
        END=$(date +%s%N)
        ELAPSED=$(( (END - START) / 1000000 ))
        if [ "$ELAPSED" -gt 0 ]; then
            awk -v e="$ELAPSED" 'BEGIN{printf "%.2f", (1024/e*1000/1024)}'
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Compara "$1 < $2" com números decimais, sem depender de 'bc -l'
speed_below_threshold() {
    awk -v s="$1" -v t="$2" 'BEGIN{exit !(s < t)}'
}

# ─────────────────────────────────────────────
# Loop principal de monitoramento
# ─────────────────────────────────────────────
monitor_loop() {
    log_event "INFO" "Monitoramento iniciado (PID $$)"
    log_event "INFO" "Intervalo de ping: ${CHECK_INTERVAL}s | Threshold velocidade: ${SPEED_DROP_THRESHOLD} Mbps"

    WAS_CONNECTED=true
    DOWNTIME_START=""
    DOWNTIME_START_EPOCH=0
    LAST_SPEED_CHECK=0

    while true; do
        NOW=$(date +%s)

        # — Verificação de conectividade —
        if check_ping; then
            if [ "$WAS_CONNECTED" = false ]; then
                # Duração calculada a partir do epoch guardado no momento da
                # queda — evita re-parsear a string de data (date -d), que
                # tem suporte inconsistente entre GNU date e o date do
                # busybox usado em imagens mínimas (ex: Alpine).
                DURATION=$(( NOW - DOWNTIME_START_EPOCH ))
                log_event "RECOVERY" "Conexão restaurada após ~${DURATION}s de queda (queda iniciada: $DOWNTIME_START)"
                WAS_CONNECTED=true
                DOWNTIME_START=""
                DOWNTIME_START_EPOCH=0
            fi
        else
            if [ "$WAS_CONNECTED" = true ]; then
                DOWNTIME_START=$(ts)
                DOWNTIME_START_EPOCH=$NOW
                log_event "DOWN" "QUEDA DE CONEXÃO detectada — sem resposta de $PING_HOST"
                WAS_CONNECTED=false
            else
                log_event "DOWN" "Conexão ainda indisponível (queda desde: $DOWNTIME_START)"
            fi
        fi

        # — Verificação de velocidade (intervalo maior) —
        if (( NOW - LAST_SPEED_CHECK >= SPEED_CHECK_INTERVAL )); then
            LAST_SPEED_CHECK=$NOW
            if [ "$WAS_CONNECTED" = true ]; then
                SPEED=$(check_speed)
                if [ "$SPEED" = "N/A" ]; then
                    log_event "INFO" "Teste de velocidade ignorado (curl indisponível — $(pkg_install_hint curl))"
                elif speed_below_threshold "$SPEED" "$SPEED_DROP_THRESHOLD"; then
                    log_event "SLOW" "QUEDA DE VELOCIDADE detectada — ${SPEED} Mbps (threshold: ${SPEED_DROP_THRESHOLD} Mbps)"
                else
                    log_event "SPEED" "Velocidade OK — ${SPEED} Mbps"
                fi
            fi
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# ─────────────────────────────────────────────
# Comandos CLI
# ─────────────────────────────────────────────
case "${1:-}" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo -e "${YELLOW}Monitoramento já está rodando (PID $(cat "$PID_FILE"))${NC}"
            exit 0
        fi
        if ! command -v curl >/dev/null 2>&1; then
            echo -e "${YELLOW}Aviso: curl não encontrado ($(pkg_install_hint curl)) — o teste de velocidade será ignorado, só quedas de conexão serão monitoradas${NC}"
        fi
        # Desanexa de stdin/stdout/stderr do terminal (equivalente a nohup),
        # pra sobreviver ao fechamento do terminal mesmo sem 'nohup' instalado
        monitor_loop </dev/null >/dev/null 2>&1 &
        disown
        echo $! > "$PID_FILE"
        echo -e "${GREEN}✓ Monitoramento iniciado em background (PID $!)${NC}"
        echo -e "  Log: ${CYAN}$LOG_FILE${NC}"
        ;;
    stop)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            kill "$(cat "$PID_FILE")"
            rm -f "$PID_FILE"
            echo -e "${GREEN}✓ Monitoramento encerrado${NC}"
        else
            echo -e "${YELLOW}Nenhum monitoramento ativo encontrado${NC}"
        fi
        ;;
    status)
        echo "=========================================="
        echo "   Status do Monitor de Internet         "
        echo "=========================================="
        echo ""
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo -e "Monitor: ${GREEN}✓ Rodando${NC} (PID $(cat "$PID_FILE"))"
        else
            echo -e "Monitor: ${RED}✗ Parado${NC}"
        fi
        echo ""
        if [ -f "$LOG_FILE" ]; then
            echo -e "${BOLD}Últimas 20 entradas do log:${NC}"
            echo "------------------------------------------"
            tail -20 "$LOG_FILE"
        else
            echo -e "${YELLOW}Nenhum log encontrado ainda${NC}"
        fi
        echo ""
        ;;
    log)
        if [ -f "$LOG_FILE" ]; then
            cat "$LOG_FILE"
        else
            echo -e "${YELLOW}Nenhum log encontrado em $LOG_FILE${NC}"
        fi
        ;;
    *)
        echo "Uso: $0 {start|stop|status|log}"
        echo ""
        echo "  start   — inicia monitoramento em background"
        echo "  stop    — para o monitoramento"
        echo "  status  — exibe status e últimas entradas do log"
        echo "  log     — exibe o log completo"
        exit 1
        ;;
esac