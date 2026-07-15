#!/usr/bin/env bash
set -uo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================================
# Funções de log
# ================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

# ================================
# 0. Detecção de distro / família / init
# ================================
DISTRO_ID="desconhecida"
DISTRO_NAME="Desconhecida"
DISTRO_FAMILY="unknown"   # debian | rhel | arch | suse | alpine | unknown

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-desconhecida}"
    DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
    ID_LIKE="${ID_LIKE:-}"
fi

case "$DISTRO_ID $ID_LIKE" in
    *fedora*|*rhel*|*centos*|*rocky*|*almalinux*) DISTRO_FAMILY="rhel" ;;
    *debian*|*ubuntu*)                            DISTRO_FAMILY="debian" ;;
    *arch*|*manjaro*|*endeavouros*)               DISTRO_FAMILY="arch" ;;
    *suse*|*opensuse*)                            DISTRO_FAMILY="suse" ;;
    *alpine*)                                     DISTRO_FAMILY="alpine" ;;
    *)
        if command -v dnf >/dev/null 2>&1;      then DISTRO_FAMILY="rhel"
        elif command -v apt >/dev/null 2>&1;    then DISTRO_FAMILY="debian"
        elif command -v pacman >/dev/null 2>&1; then DISTRO_FAMILY="arch"
        elif command -v zypper >/dev/null 2>&1; then DISTRO_FAMILY="suse"
        elif command -v apk >/dev/null 2>&1;    then DISTRO_FAMILY="alpine"
        fi
        ;;
esac

# systemd vs. init alternativo (ex: OpenRC no Alpine)
HAS_SYSTEMD=false
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi

# Sistema de imagem imutável (rpm-ostree: Silverblue/Kinoite/Bazzite/CoreOS;
# transactional-update: openSUSE MicroOS/Aeon)
IS_IMMUTABLE=false
IMMUTABLE_TOOL=""
if command -v rpm-ostree >/dev/null 2>&1; then
    IS_IMMUTABLE=true
    IMMUTABLE_TOOL="rpm-ostree"
elif command -v transactional-update >/dev/null 2>&1; then
    IS_IMMUTABLE=true
    IMMUTABLE_TOOL="transactional-update"
fi

# Nomes de pacote que variam entre famílias
pkg_name() {
    local key="$1"
    case "$DISTRO_FAMILY-$key" in
        rhel-lm-sensors)   echo "lm_sensors" ;;
        debian-lm-sensors) echo "lm-sensors" ;;
        arch-lm-sensors)   echo "lm_sensors" ;;
        suse-lm-sensors)   echo "sensors" ;;
        alpine-lm-sensors) echo "lm-sensors" ;;
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

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN}   DIAGNÓSTICO RÁPIDO DO SISTEMA ($DISTRO_NAME)${NC}"
echo -e "${CYAN}====================================${NC}"
log_info "Família: $DISTRO_FAMILY | systemd: $HAS_SYSTEMD | imutável: $IS_IMMUTABLE${IMMUTABLE_TOOL:+ ($IMMUTABLE_TOOL)}"

# =====================================
# 1. Espaço em disco
# =====================================
section "Espaço em disco (>=80% é alerta)"
df -h -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR==1 || $5+0 >= 80'

# =====================================
# 2. Memória
# =====================================
section "Memória"
free -h 2>/dev/null || log_warn "'free' não encontrado ($(pkg_install_hint procps))"

# =====================================
# 3. CPU / Load
# =====================================
section "CPU / Load"
uptime 2>/dev/null || cat /proc/loadavg 2>/dev/null || log_warn "Não foi possível obter load average"

# =====================================
# 4. Temperatura
# =====================================
section "Temperatura"
if command -v sensors >/dev/null 2>&1; then
    sensors
else
    log_warn "lm-sensors não instalado"
    if [ "$IMMUTABLE_TOOL" = "rpm-ostree" ]; then
        echo "Instalar com: rpm-ostree install $(pkg_name lm-sensors)"
    elif [ "$IMMUTABLE_TOOL" = "transactional-update" ]; then
        echo "Instalar com: sudo transactional-update pkg install $(pkg_name lm-sensors)"
    else
        echo "Instalar com: $(pkg_install_hint lm-sensors)"
    fi
fi

# =====================================
# 5. Serviços com falha
# =====================================
section "Serviços com falha"
if $HAS_SYSTEMD; then
    FAILED=$(systemctl --failed --no-pager 2>/dev/null)
    if echo "$FAILED" | grep -q "0 loaded units listed"; then
        log_success "Nenhum serviço falhou"
    else
        echo "$FAILED"
    fi
elif command -v rc-status >/dev/null 2>&1; then
    # OpenRC (Alpine e outras)
    CRASHED=$(rc-status -a 2>/dev/null | grep -i "crashed")
    if [ -z "$CRASHED" ]; then
        log_success "Nenhum serviço com falha (OpenRC)"
    else
        echo "$CRASHED"
    fi
else
    log_warn "Nenhum supervisor de serviços reconhecido (systemd/OpenRC) — checagem pulada"
fi

# =====================================
# 6. Erros críticos do boot atual
# =====================================
section "Erros críticos do boot atual"
if $HAS_SYSTEMD; then
    journalctl -p 3 -b --no-pager 2>/dev/null | tail -20 || log_success "Nenhum erro crítico"
elif [ -r /var/log/messages ]; then
    log_info "Sem journald — mostrando erros recentes de /var/log/messages"
    grep -iE "error|crit|emerg|alert" /var/log/messages 2>/dev/null | tail -20
else
    log_warn "Sem journald nem /var/log/messages legível — tentando dmesg"
    dmesg --level=err,crit,alert,emerg 2>/dev/null | tail -20 || log_warn "Não foi possível ler logs de erro do kernel"
fi

# =====================================
# 7. Erros do boot anterior
# =====================================
section "Erros do boot anterior"
if $HAS_SYSTEMD; then
    journalctl -p 3 -b -1 --no-pager 2>/dev/null | tail -20 || log_warn "Sem logs persistentes do boot anterior"
else
    log_warn "Log de boot anterior requer journald persistente — não disponível neste init"
fi

# =====================================
# 8. Integridade dos pacotes
# =====================================
section "Integridade dos pacotes"
if $IS_IMMUTABLE; then
    if [ "$IMMUTABLE_TOOL" = "rpm-ostree" ]; then
        STATUS=$(rpm-ostree status 2>/dev/null)
        if echo "$STATUS" | grep -q "Deployments:"; then
            log_success "Sistema imutável (rpm-ostree) — integridade OK"
            echo "$STATUS" | grep -E "Version|Commit|LayeredPackages" | head -10
        else
            log_warn "Não foi possível verificar o status do rpm-ostree"
        fi
    else
        log_info "Sistema imutável (transactional-update) — verifique com: transactional-update --continue status"
        if command -v snapper >/dev/null 2>&1; then
            snapper list 2>/dev/null | tail -5
        fi
    fi
else
    BROKEN=""
    case "$DISTRO_FAMILY" in
        rhel)   BROKEN=$(sudo dnf check 2>&1 | grep -i "error\|broken\|missing" || true) ;;
        debian)
            BROKEN=$(sudo apt-get check 2>&1 | grep -i "error\|broken\|missing" || true)
            [ -z "$BROKEN" ] && BROKEN=$(sudo dpkg --audit 2>&1 || true)
            ;;
        arch)   BROKEN=$(sudo pacman -Dk 2>&1 | grep -vi "^checking" || true) ;;
        suse)   BROKEN=$(sudo zypper --non-interactive verify 2>&1 | grep -i "error\|broken\|missing" || true) ;;
        alpine) BROKEN=$(sudo apk verify 2>&1 | grep -i "error\|broken\|missing" || true) ;;
        *)      log_warn "Checagem de integridade não implementada para esta distro" ;;
    esac
    if [ -z "$BROKEN" ]; then
        log_success "Nenhum pacote quebrado"
    else
        log_warn "Pacotes com problemas detectados"
        echo "$BROKEN"
    fi
fi

# =====================================
# 9. Docker
# =====================================
section "Docker"
if command -v docker >/dev/null 2>&1; then
    if $HAS_SYSTEMD; then
        if systemctl is-active --quiet docker; then
            docker ps --format "  - {{.Names}} ({{.Status}})" 2>/dev/null
        else
            log_warn "Docker instalado mas o serviço não está rodando"
            echo "Iniciar com: sudo systemctl start docker"
        fi
    elif command -v rc-service >/dev/null 2>&1; then
        if rc-service docker status 2>/dev/null | grep -qi started; then
            docker ps --format "  - {{.Names}} ({{.Status}})" 2>/dev/null
        else
            log_warn "Docker instalado mas o serviço não está rodando"
            echo "Iniciar com: sudo rc-service docker start"
        fi
    else
        log_info "Sem systemd/OpenRC reconhecido — não foi possível checar o status do serviço"
        docker ps --format "  - {{.Names}} ({{.Status}})" 2>/dev/null || true
    fi
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
    if command -v lsmod >/dev/null 2>&1 && lsmod | grep -q nvidia; then
        log_warn "Módulo NVIDIA carregado mas nvidia-smi não encontrado"
    else
        log_warn "Driver NVIDIA não carregado (ou GPU não é NVIDIA)"
    fi
fi

# =====================================
# 11. Áudio
# =====================================
section "Stack de áudio"
if command -v pactl >/dev/null 2>&1; then
    pactl info 2>/dev/null | grep -E "Server Name|Default Sink"
elif command -v pw-cli >/dev/null 2>&1; then
    log_info "PipeWire detectado"
    pw-cli info 0 2>/dev/null | grep -E "name|version" | head -5
elif command -v amixer >/dev/null 2>&1; then
    log_info "ALSA (amixer) detectado — sem PulseAudio/PipeWire"
    amixer info 2>/dev/null | head -5
else
    log_warn "Stack de áudio não encontrado"
fi

# =====================================
# 12. Flatpaks com atualização pendente
# =====================================
section "Atualizações Flatpak pendentes"
if command -v flatpak >/dev/null 2>&1; then
    UPDATES=$(flatpak remote-ls --updates 2>/dev/null)
    if [ -z "$UPDATES" ]; then
        log_success "Todos os Flatpaks estão atualizados"
    else
        log_warn "Flatpaks com atualização disponível:"
        echo "$UPDATES"
    fi
else
    log_warn "Flatpak não encontrado"
fi

echo
log_success "Diagnóstico concluído ($DISTRO_NAME)"