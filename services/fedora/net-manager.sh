#!/usr/bin/env bash
# =============================================================================
# net-manager — Gerenciador de rede para Fedora
# Funções: limpar cache DNS, otimizar TCP/rede, monitorar velocidade
# Compatível: Fedora (systemd-resolved ou NetworkManager)
# =============================================================================

set -euo pipefail

# ─── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[AVISO]${RESET} $*"; }
err()     { echo -e "${RED}[ERRO]${RESET}  $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${CYAN}  $*${RESET}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════${RESET}"; }

require_root() {
    [[ $EUID -eq 0 ]] || { err "Esta operação requer root. Use: sudo $0 $*"; exit 1; }
}

check_dep() {
    command -v "$1" &>/dev/null || {
        warn "Dependência ausente: $1 — instalando..."
        dnf install -y "$2" &>/dev/null && ok "$1 instalado." || {
            err "Falha ao instalar $1. Instale manualmente: sudo dnf install $2"
            return 1
        }
    }
}

# =============================================================================
# 1. LIMPAR CACHE DE INTERNET
# =============================================================================
clean_cache() {
    section "Limpando cache de internet"
    require_root

    # 1.1 Cache DNS (systemd-resolved)
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        info "Limpando cache DNS (systemd-resolved)..."
        systemd-resolve --flush-caches
        local stats
        stats=$(systemd-resolve --statistics 2>/dev/null | grep -i "current cache size" || true)
        ok "Cache DNS limpo. $stats"
    fi

    # 1.2 Cache DNS (NetworkManager / nscd)
    if systemctl is-active --quiet nscd 2>/dev/null; then
        info "Limpando cache nscd..."
        nscd --invalidate=hosts
        ok "Cache nscd limpo."
    fi

    # 1.3 Reiniciar NetworkManager para liberar estados de conexão
    info "Reiniciando NetworkManager..."
    systemctl restart NetworkManager
    sleep 2
    ok "NetworkManager reiniciado."

    # 1.4 Cache ARP (tabela de vizinhança)
    info "Limpando tabela ARP..."
    ip neigh flush all 2>/dev/null && ok "Tabela ARP limpa." || warn "Não foi possível limpar ARP."

    # 1.5 Cache de roteamento do kernel
    info "Limpando cache de roteamento do kernel..."
    if [[ -f /proc/sys/net/ipv4/route/flush ]]; then
        echo 1 > /proc/sys/net/ipv4/route/flush
        ok "Cache de roteamento limpo."
    fi

    # 1.6 Conntrack (tabela de conexões rastreadas)
    if command -v conntrack &>/dev/null; then
        info "Limpando tabela conntrack..."
        conntrack -F 2>/dev/null && ok "Conntrack limpo." || warn "Falha ao limpar conntrack."
    else
        warn "conntrack não encontrado — pulando (dnf install conntrack-tools para habilitar)."
    fi

    echo
    ok "Limpeza de cache concluída."
}

# =============================================================================
# 2. OTIMIZAR VELOCIDADE DE INTERNET
# =============================================================================
optimize_network() {
    section "Otimizando parâmetros de rede"
    require_root

    local SYSCTL_FILE="/etc/sysctl.d/99-net-manager-optimizations.conf"

    info "Aplicando otimizações TCP/IP via sysctl..."

    cat > "$SYSCTL_FILE" <<'EOF'
# ──────────────────────────────────────────────────────────────────
# Otimizações de rede geradas pelo net-manager
# ──────────────────────────────────────────────────────────────────

# Buffers de recepção e envio (máximo e padrão)
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 65536

# Buffers TCP específicos (mín / padrão / máx)
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Algoritmo de congestionamento: BBR (melhor para conexões modernas)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Janela inicial maior para conexões rápidas
net.ipv4.tcp_adv_win_scale = 2

# Escalonamento de janela TCP (RFC 1323)
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1

# Reutilização de sockets TIME_WAIT
net.ipv4.tcp_tw_reuse = 1

# Reduz latência em conexões curtas
net.ipv4.tcp_fastopen = 3

# Fila de conexões pendentes
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Keep-alive: detecta conexões mortas mais rápido
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# Menor latência para ACKs
net.ipv4.tcp_no_delay_ack = 1

# Encaminhamento desativado (não é roteador)
net.ipv4.ip_forward = 0

# IPv6: desativar se não usado (descomente se necessário)
# net.ipv6.conf.all.disable_ipv6 = 1
EOF

    # Aplicar imediatamente
    sysctl -p "$SYSCTL_FILE" &>/dev/null
    ok "Parâmetros sysctl aplicados em $SYSCTL_FILE"

    # Verificar se BBR está disponível
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "TCP BBR ativado com sucesso."
    else
        warn "BBR não disponível neste kernel. Verifique: modprobe tcp_bbr"
        warn "Algoritmo atual: $(sysctl -n net.ipv4.tcp_congestion_control)"
    fi

    # Configurar DNS rápido via systemd-resolved (Quad9 + Cloudflare)
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        local RESOLVED_CONF="/etc/systemd/resolved.conf.d/99-net-manager-dns.conf"
        mkdir -p "$(dirname "$RESOLVED_CONF")"
        cat > "$RESOLVED_CONF" <<'EOF'
[Resolve]
DNS=9.9.9.9 1.1.1.1 2620:fe::fe 2606:4700:4700::1111
FallbackDNS=8.8.8.8 8.8.4.4
DNSSEC=allow-downgrade
DNSOverTLS=opportunistic
Cache=yes
EOF
        systemctl restart systemd-resolved &>/dev/null
        ok "DNS configurado: Quad9 (9.9.9.9) + Cloudflare (1.1.1.1) com DNS-over-TLS."
    fi

    echo
    ok "Otimizações aplicadas. Serão mantidas após reboot via /etc/sysctl.d/."
}

# =============================================================================
# 3. MONITORAR VELOCIDADE DE INTERNET
# =============================================================================
monitor_speed() {
    section "Monitor de Velocidade de Internet"

    local MODE="${1:-live}"  # live | test

    # ── 3.1 Teste de velocidade pontual ──────────────────────────────────────
    run_speedtest() {
        if command -v speedtest-cli &>/dev/null; then
            info "Executando teste de velocidade (speedtest-cli)..."
            speedtest-cli --simple
        elif command -v speedtest &>/dev/null; then
            info "Executando teste de velocidade (Ookla speedtest)..."
            speedtest
        else
            warn "Nenhum cliente speedtest encontrado."
            info "Instale com: sudo dnf install speedtest-cli"
            info "Ou (Ookla): curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash && sudo dnf install speedtest"
            return 1
        fi
    }

    # ── 3.2 Monitor de interface em tempo real ────────────────────────────────
    monitor_live() {
        # Detectar interface ativa
        local iface
        iface=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
        [[ -z "$iface" ]] && { err "Nenhuma interface de rede ativa encontrada."; return 1; }

        info "Monitorando interface: ${BOLD}$iface${RESET} (Ctrl+C para sair)"
        echo

        # Cabeçalho
        printf "${BOLD}%-12s %14s %14s %12s %12s${RESET}\n" \
               "Hora" "Download" "Upload" "RX Total" "TX Total"
        printf '%s\n' "─────────────────────────────────────────────────────────────"

        local rx_prev tx_prev rx_cur tx_cur rx_diff tx_diff
        rx_prev=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null || echo 0)
        tx_prev=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null || echo 0)

        while true; do
            sleep 1
            rx_cur=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null || echo 0)
            tx_cur=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null || echo 0)

            rx_diff=$(( rx_cur - rx_prev ))
            tx_diff=$(( tx_cur - tx_prev ))

            rx_prev=$rx_cur
            tx_prev=$tx_cur

            # Converter para Kbps
            local rx_kbps tx_kbps rx_mbps tx_mbps
            rx_kbps=$(( rx_diff * 8 / 1024 ))
            tx_kbps=$(( tx_diff * 8 / 1024 ))

            # Formatar saída
            local rx_label tx_label
            if (( rx_kbps >= 1024 )); then
                rx_label="$(awk "BEGIN{printf \"%.1f Mbps\", $rx_kbps/1024}")"
            else
                rx_label="${rx_kbps} Kbps"
            fi

            if (( tx_kbps >= 1024 )); then
                tx_label="$(awk "BEGIN{printf \"%.1f Mbps\", $tx_kbps/1024}")"
            else
                tx_label="${tx_kbps} Kbps"
            fi

            # Totais legíveis
            local rx_total_label tx_total_label
            rx_total_label=$(numfmt --to=iec-i --suffix=B "$rx_cur" 2>/dev/null || echo "${rx_cur}B")
            tx_total_label=$(numfmt --to=iec-i --suffix=B "$tx_cur" 2>/dev/null || echo "${tx_cur}B")

            # Cor por velocidade
            local rx_color tx_color
            (( rx_kbps > 5120 )) && rx_color="$GREEN" || rx_color="$RESET"
            (( tx_kbps > 1024 )) && tx_color="$GREEN" || tx_color="$RESET"

            printf "%-12s ${rx_color}%14s${RESET} ${tx_color}%14s${RESET} %12s %12s\n" \
                   "$(date +%H:%M:%S)" \
                   "$rx_label" "$tx_label" \
                   "$rx_total_label" "$tx_total_label"
        done
    }

    # ── 3.3 Latência (ping) ───────────────────────────────────────────────────
    check_latency() {
        info "Verificando latência para servidores de referência..."
        echo
        local hosts=("8.8.8.8:Google DNS" "1.1.1.1:Cloudflare" "9.9.9.9:Quad9")
        printf "${BOLD}%-20s %10s %10s %10s${RESET}\n" "Host" "Mín" "Média" "Máx"
        printf '%s\n' "───────────────────────────────────────────────"
        for entry in "${hosts[@]}"; do
            local host="${entry%%:*}" label="${entry##*:}"
            local result
            result=$(ping -c 4 -q "$host" 2>/dev/null | tail -1 | awk -F'/' '{printf "%.1f ms   %.1f ms   %.1f ms", $4, $5, $6}')
            if [[ -n "$result" ]]; then
                printf "%-20s %s\n" "$label ($host)" "$result"
            else
                printf "%-20s ${RED}%s${RESET}\n" "$label ($host)" "inacessível"
            fi
        done
    }

    # ── Dispatcher ────────────────────────────────────────────────────────────
    case "$MODE" in
        live)   monitor_live ;;
        test)   run_speedtest; echo; check_latency ;;
        ping)   check_latency ;;
        *)      err "Modo inválido: $MODE. Use: live | test | ping" ;;
    esac
}

# =============================================================================
# MENU PRINCIPAL
# =============================================================================
usage() {
    echo -e "${BOLD}Uso:${RESET} $(basename "$0") <comando> [opções]"
    echo
    echo -e "${BOLD}Comandos:${RESET}"
    echo -e "  ${CYAN}clean${RESET}           Limpa cache DNS, ARP, rotas e conntrack"
    echo -e "  ${CYAN}optimize${RESET}        Aplica otimizações TCP/BBR e configura DNS rápido"
    echo -e "  ${CYAN}monitor${RESET}         Monitor de throughput em tempo real (padrão)"
    echo -e "  ${CYAN}monitor test${RESET}    Teste de velocidade + latência"
    echo -e "  ${CYAN}monitor ping${RESET}    Apenas verifica latência"
    echo -e "  ${CYAN}all${RESET}             Executa clean + optimize + monitor test"
    echo
    echo -e "${BOLD}Exemplos:${RESET}"
    echo -e "  sudo $(basename "$0") clean"
    echo -e "  sudo $(basename "$0") optimize"
    echo -e "  $(basename "$0") monitor"
    echo -e "  $(basename "$0") monitor test"
    echo -e "  sudo $(basename "$0") all"
}

main() {
    case "${1:-}" in
        clean)    clean_cache ;;
        optimize) optimize_network ;;
        monitor)  monitor_speed "${2:-live}" ;;
        all)
            clean_cache
            optimize_network
            monitor_speed test
            ;;
        help|--help|-h|"") usage ;;
        *) err "Comando desconhecido: $1"; echo; usage; exit 1 ;;
    esac
}

main "$@"
