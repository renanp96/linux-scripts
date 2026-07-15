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
# 0. Detecção de distro / família
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

if [ "$DISTRO_FAMILY" = "unknown" ]; then
    log_error "Não foi possível detectar a família da distro (sem dnf/apt/pacman/zypper/apk)."
    exit 1
fi

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN}   ATUALIZAÇÃO DO SISTEMA ($DISTRO_NAME)${NC}"
echo -e "${CYAN}====================================${NC}"
log_info "Família de distro detectada: $DISTRO_FAMILY"

# =====================================
# 1. Verificação de rede
# =====================================
section "Verificando conexão de rede"

if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    log_success "Conexão com internet detectada"
else
    log_error "Sem conexão com internet"
    exit 1
fi

# =====================================
# 2. Atualizar lista de pacotes
# =====================================
section "Atualizando lista de pacotes"

case "$DISTRO_FAMILY" in
    rhel)   sudo dnf check-update || true ;;
    debian) sudo apt update || log_warn "Falha ao atualizar lista de pacotes (apt update)" ;;
    arch)   sudo pacman -Sy || log_warn "Falha ao sincronizar bases de dados (pacman -Sy)" ;;
    suse)   sudo zypper --non-interactive refresh || log_warn "Falha ao atualizar repositórios (zypper refresh)" ;;
    alpine) sudo apk update || log_warn "Falha ao atualizar índice de pacotes (apk update)" ;;
esac

# =====================================
# 3. Atualizar sistema
# =====================================
section "Atualizando pacotes instalados"

case "$DISTRO_FAMILY" in
    rhel)   sudo dnf upgrade -y ;;
    debian) sudo apt upgrade -y ;;
    arch)   sudo pacman -Syu --noconfirm ;;
    suse)   sudo zypper --non-interactive update ;;
    alpine) sudo apk upgrade ;;
esac

# =====================================
# 4. Remover pacotes desnecessários / limpar cache
# =====================================
section "Removendo pacotes antigos"

case "$DISTRO_FAMILY" in
    rhel)
        sudo dnf autoremove -y
        sudo dnf clean all
        ;;
    debian)
        sudo apt autoremove -y
        sudo apt clean
        ;;
    arch)
        # Pacotes órfãos (instalados como dependência e não mais requeridos)
        ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
        if [ -n "$ORPHANS" ]; then
            # shellcheck disable=SC2086
            sudo pacman -Rns --noconfirm $ORPHANS
        else
            log_info "Nenhum pacote órfão encontrado"
        fi
        sudo pacman -Sc --noconfirm
        ;;
    suse)
        ORPHANED=$(zypper --non-interactive packages --orphaned 2>/dev/null | awk -F'|' 'NR>4 {print $3}' | xargs || true)
        if [ -n "$ORPHANED" ]; then
            # shellcheck disable=SC2086
            sudo zypper --non-interactive remove $ORPHANED || log_warn "Falha ao remover pacotes órfãos"
        else
            log_info "Nenhum pacote órfão encontrado"
        fi
        sudo zypper clean --all
        ;;
    alpine)
        log_info "Alpine não tem um equivalente direto a 'autoremove' — pulando"
        sudo apk cache clean 2>/dev/null || log_warn "Falha ao limpar cache do apk"
        ;;
esac

# =====================================
# 5. Verificar pacotes quebrados
# =====================================
section "Verificando pacotes quebrados"

BROKEN=""
case "$DISTRO_FAMILY" in
    rhel)
        BROKEN=$(sudo dnf check 2>&1 | grep -i "error\|broken\|missing" || true)
        ;;
    debian)
        BROKEN=$(sudo apt-get check 2>&1 | grep -i "error\|broken\|missing" || true)
        if [ -z "$BROKEN" ]; then
            # dpkg --audit aponta pacotes em estado inconsistente
            BROKEN=$(sudo dpkg --audit 2>&1 || true)
        fi
        ;;
    arch)
        BROKEN=$(sudo pacman -Dk 2>&1 | grep -vi "^checking" || true)
        ;;
    suse)
        BROKEN=$(sudo zypper --non-interactive verify 2>&1 | grep -i "error\|broken\|missing" || true)
        ;;
    alpine)
        BROKEN=$(sudo apk verify 2>&1 | grep -i "error\|broken\|missing" || true)
        ;;
esac

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

case "$DISTRO_FAMILY" in
    rhel)
        if command -v needs-restarting >/dev/null 2>&1; then
            if needs-restarting -r &>/dev/null; then
                log_success "Nenhuma reinicialização necessária"
            else
                log_warn "Reinicialização do sistema é recomendada"
            fi
        else
            log_warn "'needs-restarting' não encontrado (pacote dnf-utils/yum-utils) — não foi possível checar"
        fi
        ;;
    debian)
        if [ -f /var/run/reboot-required ]; then
            log_warn "Reinicialização do sistema é recomendada"
            [ -f /var/run/reboot-required.pkgs ] && cat /var/run/reboot-required.pkgs
        else
            log_success "Nenhuma reinicialização necessária"
        fi
        ;;
    arch)
        RUNNING_KERNEL=$(uname -r)
        INSTALLED_KERNEL=$(pacman -Q linux 2>/dev/null | awk '{print $2}' || true)
        if [ -n "$INSTALLED_KERNEL" ] && [[ "$RUNNING_KERNEL" != *"${INSTALLED_KERNEL%%-*}"* ]]; then
            log_warn "Kernel instalado parece diferente do em execução — reinicialização recomendada"
        else
            log_success "Nenhuma reinicialização necessária (heurística de kernel)"
        fi
        ;;
    suse)
        if command -v zypper >/dev/null 2>&1; then
            # -r/--reboothint: retorna 1 se reboot for necessário, 0 caso contrário
            if zypper needs-restarting -r >/dev/null 2>&1; then
                log_success "Nenhuma reinicialização necessária"
            else
                log_warn "Reinicialização do sistema é recomendada"
            fi
        else
            log_warn "'zypper' não encontrado — não foi possível checar necessidade de reboot"
        fi
        ;;
    alpine)
        log_warn "Alpine não possui checagem padrão de reboot — verifique manualmente se o kernel foi atualizado"
        ;;
esac

# =====================================
# 7. Flatpak (se instalado)
# =====================================
section "Atualizando Flatpak"

if command -v flatpak >/dev/null 2>&1; then
    log_info "Flatpak encontrado — atualizando aplicações"
    if flatpak update -y; then
        log_success "Flatpak atualizado"
    else
        log_warn "Falha ao atualizar pacotes Flatpak"
    fi
else
    log_info "Flatpak não instalado — pulando"
fi

echo
log_success "Atualização do sistema concluída ($DISTRO_NAME)"