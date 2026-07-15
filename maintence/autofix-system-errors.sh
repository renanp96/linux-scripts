#!/usr/bin/env bash

# ============================================
#   Correção Automática do Sistema
#   Versão 3.0 — multi-distro
# ============================================

set -uo pipefail

# Captura o usuário real antes da elevação
REAL_USER=${SUDO_USER:-$USER}

# Auto-elevação para root
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ================================
# Detecção de distro / família / init
# ================================
DISTRO_ID="desconhecida"
DISTRO_NAME="Desconhecida"
DISTRO_FAMILY="unknown"

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

if [ "$DISTRO_FAMILY" = "unknown" ]; then
    echo -e "${RED}Não foi possível detectar a família da distro. Abortando.${NC}"
    exit 1
fi

HAS_SYSTEMD=false
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi

# Sistema de imagem imutável: rpm-ostree (Silverblue/Kinoite/Bazzite/CoreOS)
# ou transactional-update (openSUSE MicroOS/Aeon)
IMMUTABLE=false
IMMUTABLE_TOOL=""
if command -v rpm-ostree >/dev/null 2>&1; then
    IMMUTABLE=true
    IMMUTABLE_TOOL="rpm-ostree"
elif command -v transactional-update >/dev/null 2>&1; then
    IMMUTABLE=true
    IMMUTABLE_TOOL="transactional-update"
fi

# Log de execução
LOG_FILE="/var/log/correcao-sistema.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo
echo "======================================"
echo "  Execução: $(date '+%d/%m/%Y %H:%M:%S')"
echo "  Distro: $DISTRO_NAME ($DISTRO_FAMILY)"
if $IMMUTABLE; then
    echo "  Modo: Sistema Imutável ($IMMUTABLE_TOOL)"
else
    echo "  Modo: Gerenciador de pacotes padrão"
fi
echo "  systemd: $HAS_SYSTEMD"
echo "======================================"

echo
echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}   Correção Automática do Sistema${NC}"
echo -e "${BLUE}====================================${NC}"
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}1. Verificando espaço em disco...${NC}"
df -h /
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}2. Verificando saúde dos discos (SMART)...${NC}"
if command -v smartctl &>/dev/null; then
    for disk in /dev/sd? /dev/nvme?; do
        [ -e "$disk" ] || continue
        result=$(smartctl -H "$disk" 2>/dev/null | grep "result:")
        if [[ -n "$result" ]]; then
            echo -e "  $disk: $result"
        fi
    done
else
    echo -e "${YELLOW}smartmontools não instalado, pulando verificação SMART${NC}"
    case "$IMMUTABLE_TOOL" in
        rpm-ostree)           echo "  Instalar com: rpm-ostree install smartmontools" ;;
        transactional-update) echo "  Instalar com: sudo transactional-update pkg install smartmontools" ;;
        *)
            case "$DISTRO_FAMILY" in
                rhel)   echo "  Instalar com: sudo dnf install smartmontools" ;;
                debian) echo "  Instalar com: sudo apt install smartmontools" ;;
                arch)   echo "  Instalar com: sudo pacman -S smartmontools" ;;
                suse)   echo "  Instalar com: sudo zypper install smartmontools" ;;
                alpine) echo "  Instalar com: sudo apk add smartmontools" ;;
            esac
            ;;
    esac
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}3. Verificando locks do gerenciador de pacotes...${NC}"
# Para gerenciadores onde não temos 100% de certeza de que remover o lock
# é seguro (apt/zypper/apk têm mecanismos de lock mais sutis, com múltiplos
# arquivos e semânticas que mudaram entre versões), preferimos SÓ detectar
# processo em execução e avisar, sem apagar nada. Só removemos lock de forma
# automática nos casos documentados e amplamente usados: dnf/rpm e pacman.
if $IMMUTABLE; then
    if [ "$IMMUTABLE_TOOL" = "rpm-ostree" ] && pgrep -x rpm-ostree >/dev/null 2>&1; then
        echo -e "${RED}rpm-ostree em uso por outro processo! Aguarde e tente novamente.${NC}"
        exit 1
    elif [ "$IMMUTABLE_TOOL" = "transactional-update" ] && pgrep -x transactional-up >/dev/null 2>&1; then
        echo -e "${RED}transactional-update em uso por outro processo! Aguarde e tente novamente.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Nenhum lock ativo detectado${NC}"
else
    case "$DISTRO_FAMILY" in
        rhel)
            if fuser /var/lib/rpm/.rpm.lock >/dev/null 2>&1; then
                echo -e "${RED}DNF em uso por outro processo! Aguarde e tente novamente.${NC}"
                exit 1
            fi
            rm -f /var/lib/rpm/.rpm.lock
            echo -e "${GREEN}Locks removidos${NC}"
            ;;
        arch)
            if pgrep -x pacman >/dev/null 2>&1; then
                echo -e "${RED}pacman em uso por outro processo! Aguarde e tente novamente.${NC}"
                exit 1
            fi
            if [ -f /var/lib/pacman/db.lck ]; then
                rm -f /var/lib/pacman/db.lck
                echo -e "${GREEN}Lock do pacman removido${NC}"
            else
                echo -e "${GREEN}Nenhum lock ativo${NC}"
            fi
            ;;
        debian)
            if pgrep -x apt >/dev/null 2>&1 || pgrep -x apt-get >/dev/null 2>&1 || pgrep -x dpkg >/dev/null 2>&1; then
                echo -e "${RED}apt/dpkg em uso por outro processo! Aguarde e tente novamente.${NC}"
                exit 1
            fi
            echo -e "${GREEN}Nenhum processo apt/dpkg ativo${NC}"
            echo -e "${YELLOW}(locks do apt/dpkg não são removidos automaticamente — são vários arquivos"
            echo -e "e apagar às cegas pode corromper o estado do dpkg; se necessário, remova manualmente"
            echo -e "/var/lib/dpkg/lock-frontend, /var/lib/dpkg/lock e /var/cache/apt/archives/lock)${NC}"
            ;;
        suse)
            if pgrep -x zypper >/dev/null 2>&1; then
                echo -e "${RED}zypper em uso por outro processo! Aguarde e tente novamente.${NC}"
                exit 1
            fi
            echo -e "${GREEN}Nenhum processo zypper ativo${NC}"
            ;;
        alpine)
            if pgrep -x apk >/dev/null 2>&1; then
                echo -e "${RED}apk em uso por outro processo! Aguarde e tente novamente.${NC}"
                exit 1
            fi
            echo -e "${GREEN}Nenhum processo apk ativo${NC}"
            ;;
    esac
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}4. Corrigindo pacotes quebrados...${NC}"
if $IMMUTABLE; then
    echo -e "${YELLOW}Sistema imutável — verificando integridade via $IMMUTABLE_TOOL...${NC}"
    if [ "$IMMUTABLE_TOOL" = "rpm-ostree" ]; then
        rpm-ostree status || echo -e "${RED}Falha ao verificar status — verifique manualmente${NC}"
    else
        transactional-update --continue status 2>/dev/null || echo -e "${YELLOW}Use: transactional-update dup (aplica na próxima reinicialização)${NC}"
    fi
else
    case "$DISTRO_FAMILY" in
        rhel)
            dnf check || echo -e "${RED}Falha ao verificar pacotes — verifique manualmente${NC}"
            dnf distro-sync -y || echo -e "${RED}Falha ao sincronizar pacotes${NC}"
            ;;
        debian)
            apt-get check || echo -e "${RED}Falha ao verificar pacotes — verifique manualmente${NC}"
            apt --fix-broken install -y || echo -e "${RED}Falha ao corrigir dependências quebradas${NC}"
            ;;
        arch)
            # pacman não tem um "distro-sync" dedicado; -Syu já realinha
            # pacotes com os repositórios. Não há reinstalação automática
            # segura de "todos os pacotes" sem risco, então não fizemos isso aqui.
            pacman -Syu --noconfirm || echo -e "${RED}Falha ao sincronizar pacotes${NC}"
            ;;
        suse)
            zypper --non-interactive verify || echo -e "${RED}Falha ao verificar pacotes — verifique manualmente${NC}"
            zypper --non-interactive dup || echo -e "${RED}Falha ao sincronizar pacotes (dup)${NC}"
            ;;
        alpine)
            apk fix || echo -e "${RED}Falha ao corrigir pacotes${NC}"
            ;;
    esac
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}5. Reconfigurando pacotes pendentes...${NC}"
if $IMMUTABLE; then
    echo -e "${YELLOW}Sistema imutável — reconfiguração de pacotes não aplicável${NC}"
else
    case "$DISTRO_FAMILY" in
        rhel|suse)
            rpm --rebuilddb || echo -e "${RED}Falha ao reconstruir banco de dados RPM${NC}"
            ;;
        debian)
            dpkg --configure -a || echo -e "${RED}Falha ao reconfigurar pacotes pendentes${NC}"
            ;;
        arch|alpine)
            echo -e "${YELLOW}Sem equivalente direto nesta família — não aplicável${NC}"
            ;;
    esac
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}6. Limpando cache do gerenciador de pacotes...${NC}"
if $IMMUTABLE; then
    if [ "$IMMUTABLE_TOOL" = "rpm-ostree" ]; then
        rpm-ostree cleanup -m
    else
        echo -e "${YELLOW}transactional-update: limpeza de snapshots antigos via 'snapper' se necessário${NC}"
    fi
else
    case "$DISTRO_FAMILY" in
        rhel)
            dnf clean all
            dnf autoremove -y
            ;;
        debian)
            apt clean
            apt autoremove -y
            ;;
        arch)
            ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
            [ -n "$ORPHANS" ] && pacman -Rns --noconfirm $ORPHANS
            pacman -Sc --noconfirm
            ;;
        suse)
            ORPHANED=$(zypper --non-interactive packages --orphaned 2>/dev/null | awk -F'|' 'NR>4 {print $3}' | xargs || true)
            [ -n "$ORPHANED" ] && zypper --non-interactive remove $ORPHANED
            zypper clean --all
            ;;
        alpine)
            apk cache clean 2>/dev/null || true
            ;;
    esac
fi
# Flatpak não é específico de nenhuma família — limpamos sempre que presente
if command -v flatpak >/dev/null 2>&1; then
    flatpak uninstall --unused -y 2>/dev/null && echo -e "${GREEN}Flatpaks não utilizados removidos${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}7. Verificando conexão de rede...${NC}"
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}Rede OK${NC}"
    if $IMMUTABLE; then
        if [ "$IMMUTABLE_TOOL" = "rpm-ostree" ]; then
            echo "Verificando atualizações disponíveis via rpm-ostree..."
            rpm-ostree upgrade --check || echo -e "${YELLOW}Não foi possível verificar atualizações${NC}"
        else
            echo -e "${YELLOW}transactional-update aplica atualizações via snapshot — rode 'transactional-update dup' e reinicie${NC}"
        fi
    else
        echo "Atualizando lista de pacotes..."
        case "$DISTRO_FAMILY" in
            rhel)   dnf check-update || true ;;
            debian) apt update || true ;;
            arch)   pacman -Sy || true ;;
            suse)   zypper --non-interactive refresh || true ;;
            alpine) apk update || true ;;
        esac
    fi
    if command -v flatpak >/dev/null 2>&1; then
        echo "Verificando atualizações Flatpak..."
        flatpak update -y 2>/dev/null || echo -e "${YELLOW}Falha ao atualizar Flatpaks${NC}"
    fi
else
    echo -e "${RED}Sem conexão com internet — pulando verificação de atualizações${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}8. Reiniciando serviços problemáticos...${NC}"
if $HAS_SYSTEMD; then
    systemctl daemon-reexec
    systemctl reset-failed
    echo
    echo -e "${YELLOW}Serviços com falha:${NC}"
    systemctl --failed
else
    echo -e "${YELLOW}Sem systemd — 'daemon-reexec'/'reset-failed' não se aplicam neste init${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}9. Corrigindo initramfs...${NC}"
if $IMMUTABLE && [ "$IMMUTABLE_TOOL" = "rpm-ostree" ]; then
    echo -e "${YELLOW}Sistema imutável — initramfs gerenciado pelo rpm-ostree${NC}"
    echo "Para rebuild use: rpm-ostree initramfs --enable"
else
    case "$DISTRO_FAMILY" in
        rhel)   dracut --force || echo -e "${RED}Falha ao atualizar initramfs${NC}" ;;
        debian) update-initramfs -u -k all || echo -e "${RED}Falha ao atualizar initramfs${NC}" ;;
        arch)   mkinitcpio -P || echo -e "${RED}Falha ao atualizar initramfs${NC}" ;;
        suse)   dracut --force || echo -e "${RED}Falha ao atualizar initramfs${NC}" ;;
        alpine) mkinitfs || echo -e "${RED}Falha ao atualizar initramfs${NC}" ;;
    esac
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}10. Reiniciando stack de áudio...${NC}"
if $HAS_SYSTEMD; then
    if sudo -u "$REAL_USER" systemctl --user is-active pipewire >/dev/null 2>&1; then
        sudo -u "$REAL_USER" systemctl --user restart pipewire pipewire-pulse wireplumber
        echo -e "${GREEN}PipeWire reiniciado para usuário $REAL_USER${NC}"
    elif sudo -u "$REAL_USER" systemctl --user is-active pulseaudio >/dev/null 2>&1; then
        sudo -u "$REAL_USER" pulseaudio -k
        echo -e "${GREEN}PulseAudio reiniciado para usuário $REAL_USER${NC}"
    else
        echo -e "${YELLOW}Nenhum stack de áudio ativo${NC}"
    fi
else
    if command -v pulseaudio >/dev/null 2>&1; then
        sudo -u "$REAL_USER" pulseaudio -k 2>/dev/null && echo -e "${GREEN}PulseAudio reiniciado${NC}"
    else
        echo -e "${YELLOW}Sem systemd --user — reinício automático do áudio não suportado neste init${NC}"
    fi
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}11. Garantindo logs persistentes...${NC}"
if $HAS_SYSTEMD; then
    mkdir -p /var/log/journal
    systemctl restart systemd-journald
    echo -e "${GREEN}Logs persistentes garantidos (journald)${NC}"
else
    echo -e "${YELLOW}Sem journald — logs geralmente já são persistentes via syslog/rsyslog por padrão${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}12. Verificação do sistema de arquivos...${NC}"
ROOT_DEV=$(findmnt -n -o SOURCE /)
FS_TYPE=$(findmnt -n -o FSTYPE /)

# A checagem depende do TIPO de sistema de arquivos, não da família da
# distro nem de ela ser imutável — qualquer distro pode rodar btrfs/ext4/xfs.
case "$FS_TYPE" in
    btrfs)
        if command -v btrfs >/dev/null 2>&1; then
            btrfs scrub start / && echo -e "${GREEN}btrfs scrub iniciado em segundo plano${NC}"
        else
            echo -e "${YELLOW}btrfs-progs não encontrado${NC}"
        fi
        ;;
    ext4)
        if tune2fs -C 1 "$ROOT_DEV" >/dev/null 2>&1; then
            echo -e "${GREEN}fsck agendado para o próximo boot em $ROOT_DEV${NC}"
        else
            echo -e "${YELLOW}Não foi possível agendar fsck automaticamente${NC}"
        fi
        ;;
    xfs)
        xfs_repair -n "$ROOT_DEV" 2>/dev/null && echo -e "${GREEN}XFS verificado (somente leitura)${NC}" \
            || echo -e "${YELLOW}XFS: reparo completo requer modo single-user${NC}"
        ;;
    *)
        echo -e "${YELLOW}Sistema de arquivos $FS_TYPE — verificação manual recomendada${NC}"
        ;;
esac
echo

# ─────────────────────────────────────────
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  Correção concluída com sucesso!${NC}"
echo -e "${GREEN}  Log salvo em: $LOG_FILE${NC}"
echo -e "${GREEN}====================================${NC}"
echo
echo -e "${YELLOW}Reinicie o sistema se os problemas persistirem.${NC}"
echo