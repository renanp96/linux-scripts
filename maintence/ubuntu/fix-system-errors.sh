#!/bin/bash
# ============================================
#   Correção Automática do Sistema
#   Versão 2.0
# ============================================

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

# Log de execução
LOG_FILE="/var/log/correcao-sistema.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo
echo "======================================"
echo "  Execução: $(date '+%d/%m/%Y %H:%M:%S')"
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
    for disk in /dev/sd?; do
        result=$(smartctl -H "$disk" 2>/dev/null | grep "result:")
        if [[ -n "$result" ]]; then
            echo -e "  $disk: $result"
        fi
    done
else
    echo -e "${YELLOW}smartmontools não instalado, pulando verificação SMART${NC}"
fi
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}3. Removendo locks do APT (se existirem)...${NC}"
if fuser /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock >/dev/null 2>&1; then
    echo -e "${RED}APT em uso por outro processo! Aguarde e tente novamente.${NC}"
    exit 1
fi
rm -f /var/lib/dpkg/lock
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/cache/apt/archives/lock
echo -e "${GREEN}Locks removidos${NC}"
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}4. Corrigindo pacotes quebrados...${NC}"
apt --fix-broken install -y || echo -e "${RED}Falha ao corrigir pacotes — verifique manualmente${NC}"
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}5. Reconfigurando pacotes pendentes...${NC}"
dpkg --configure -a || echo -e "${RED}Falha ao reconfigurar pacotes${NC}"
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}6. Limpando cache APT...${NC}"
apt clean
apt autoclean
apt autoremove -y
echo

# ─────────────────────────────────────────
echo -e "${YELLOW}7. Verificando conexão de rede...${NC}"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}Rede OK${NC}"
    echo "Atualizando lista de pacotes..."
    apt update || echo -e "${RED}Falha ao atualizar lista de pacotes${NC}"
else
    echo -e "${RED}Sem conexão com internet — pulando apt update${NC}"
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
update-initramfs -u || echo -e "${RED}Falha ao atualizar initramfs${NC}"
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
echo -e "${YELLOW}12. Agendando verificação do sistema de arquivos no próximo boot...${NC}"
ROOT_DEV=$(findmnt -n -o SOURCE /)
if tune2fs -C 1 "$ROOT_DEV" >/dev/null 2>&1; then
    echo -e "${GREEN}fsck agendado para o próximo boot em $ROOT_DEV${NC}"
else
    echo -e "${YELLOW}Não foi possível agendar fsck automaticamente${NC}"
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