#!/bin/bash
# ============================================
#   Correção Automática do Sistema
#   Versão 2.0 — Fedora/Bazzite
# ============================================

# Captura o usuário real antes da elevação
REAL_USER=${SUDO_USER:-$USER}

# Auto-elevação para root
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Detecta se é sistema imutável (Bazzite, Silverblue, etc.)
IMMUTABLE=false
if command -v rpm-ostree >/dev/null 2>&1; then
    IMMUTABLE=true
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log de execução
LOG_FILE="/var/log/correcao-sistema.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo
echo "======================================"
echo "  Execução: $(date '+%d/%m/%Y %H:%M:%S')"
if [ "$IMMUTABLE" = true ]; then
    echo "  Modo: Sistema Imutável (rpm-ostree)"
else
    echo "  Modo: Fedora padrão (dnf)"
fi
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
    if [ "$IMMUTABLE" = true ]; then
        echo "  Instalar com: rpm-ostree install smartmontools"
    else
        echo "  Instalar com: sudo dnf install smartmontools"
    fi
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}3. Verificando locks do gerenciador de pacotes...${NC}"
if [ "$IMMUTABLE" = true ]; then
    # rpm-ostree não usa locks como o APT
    if pgrep -x rpm-ostree >/dev/null 2>&1; then
        echo -e "${RED}rpm-ostree em uso por outro processo! Aguarde e tente novamente.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Nenhum lock ativo no rpm-ostree${NC}"
else
    # Fedora padrão — verifica lock do dnf
    if fuser /var/lib/rpm/.rpm.lock >/dev/null 2>&1; then
        echo -e "${RED}DNF em uso por outro processo! Aguarde e tente novamente.${NC}"
        exit 1
    fi
    rm -f /var/lib/rpm/.rpm.lock
    echo -e "${GREEN}Locks removidos${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}4. Corrigindo pacotes quebrados...${NC}"
if [ "$IMMUTABLE" = true ]; then
    echo -e "${YELLOW}Sistema imutável — verificando integridade via rpm-ostree...${NC}"
    rpm-ostree status || echo -e "${RED}Falha ao verificar status — verifique manualmente${NC}"
else
    sudo dnf check || echo -e "${RED}Falha ao verificar pacotes — verifique manualmente${NC}"
    sudo dnf distro-sync -y || echo -e "${RED}Falha ao sincronizar pacotes${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}5. Reconfigurando pacotes pendentes...${NC}"
if [ "$IMMUTABLE" = true ]; then
    echo -e "${YELLOW}Sistema imutável — reconfiguração de pacotes não aplicável${NC}"
else
    sudo rpm --rebuilddb || echo -e "${RED}Falha ao reconstruir banco de dados RPM${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}6. Limpando cache do gerenciador de pacotes...${NC}"
if [ "$IMMUTABLE" = true ]; then
    rpm-ostree cleanup -m
    flatpak uninstall --unused -y 2>/dev/null && echo -e "${GREEN}Flatpaks não utilizados removidos${NC}"
else
    sudo dnf clean all
    sudo dnf autoremove -y
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}7. Verificando conexão de rede...${NC}"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}Rede OK${NC}"
    if [ "$IMMUTABLE" = true ]; then
        echo "Verificando atualizações disponíveis via rpm-ostree..."
        rpm-ostree upgrade --check || echo -e "${YELLOW}Não foi possível verificar atualizações${NC}"
        echo "Verificando atualizações Flatpak..."
        flatpak update -y 2>/dev/null || echo -e "${YELLOW}Falha ao atualizar Flatpaks${NC}"
    else
        echo "Atualizando lista de pacotes..."
        sudo dnf check-update || true
    fi
else
    echo -e "${RED}Sem conexão com internet — pulando verificação de atualizações${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}8. Reiniciando serviços problemáticos...${NC}"
systemctl daemon-reexec
systemctl reset-failed
echo

echo -e "${YELLOW}Serviços com falha:${NC}"
systemctl --failed
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}9. Corrigindo initramfs...${NC}"
if [ "$IMMUTABLE" = true ]; then
    echo -e "${YELLOW}Sistema imutável — initramfs gerenciado pelo rpm-ostree${NC}"
    echo "Para rebuild use: rpm-ostree initramfs --enable"
else
    dracut --force || echo -e "${RED}Falha ao atualizar initramfs${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}10. Reiniciando stack de áudio...${NC}"
if sudo -u "$REAL_USER" systemctl --user is-active pipewire >/dev/null 2>&1; then
    sudo -u "$REAL_USER" systemctl --user restart pipewire pipewire-pulse wireplumber
    echo -e "${GREEN}PipeWire reiniciado para usuário $REAL_USER${NC}"
elif sudo -u "$REAL_USER" systemctl --user is-active pulseaudio >/dev/null 2>&1; then
    sudo -u "$REAL_USER" pulseaudio -k
    echo -e "${GREEN}PulseAudio reiniciado para usuário $REAL_USER${NC}"
else
    echo -e "${YELLOW}Nenhum stack de áudio ativo${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}11. Garantindo logs persistentes...${NC}"
mkdir -p /var/log/journal
systemctl restart systemd-journald
echo -e "${GREEN}Logs persistentes garantidos${NC}"
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}12. Verificação do sistema de arquivos...${NC}"
ROOT_DEV=$(findmnt -n -o SOURCE /)
FS_TYPE=$(findmnt -n -o FSTYPE /)

if [ "$IMMUTABLE" = true ]; then
    echo -e "${YELLOW}Sistema imutável usa btrfs — verificando com btrfs scrub...${NC}"
    if command -v btrfs >/dev/null 2>&1; then
        btrfs scrub start / && echo -e "${GREEN}btrfs scrub iniciado em segundo plano${NC}"
    else
        echo -e "${YELLOW}btrfs-progs não encontrado${NC}"
    fi
elif [[ "$FS_TYPE" == "ext4" ]]; then
    if tune2fs -C 1 "$ROOT_DEV" >/dev/null 2>&1; then
        echo -e "${GREEN}fsck agendado para o próximo boot em $ROOT_DEV${NC}"
    else
        echo -e "${YELLOW}Não foi possível agendar fsck automaticamente${NC}"
    fi
elif [[ "$FS_TYPE" == "xfs" ]]; then
    # XFS — verificação online
    xfs_repair -n "$ROOT_DEV" 2>/dev/null && echo -e "${GREEN}XFS verificado (somente leitura)${NC}" \
        || echo -e "${YELLOW}XFS: reparo completo requer modo single-user${NC}"
else
    echo -e "${YELLOW}Sistema de arquivos $FS_TYPE — verificação manual recomendada${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  Correção concluída com sucesso!${NC}"
echo -e "${GREEN}  Log salvo em: $LOG_FILE${NC}"
echo -e "${GREEN}====================================${NC}"
echo
echo -e "${YELLOW}Reinicie o sistema se os problemas persistirem.${NC}"
echo