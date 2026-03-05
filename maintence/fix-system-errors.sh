#!/bin/bash

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

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}   Correção Automática do Sistema${NC}"
echo -e "${BLUE}====================================${NC}"

echo
echo -e "${YELLOW}1. Verificando espaço em disco...${NC}"
df -h /

echo
echo -e "${YELLOW}2. Removendo locks do APT (se existirem)...${NC}"
rm -f /var/lib/dpkg/lock
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/cache/apt/archives/lock

echo
echo -e "${YELLOW}3. Corrigindo pacotes quebrados...${NC}"
apt --fix-broken install -y

echo
echo -e "${YELLOW}4. Reconfigurando pacotes pendentes...${NC}"
dpkg --configure -a

echo
echo -e "${YELLOW}5. Limpando cache APT...${NC}"
apt clean
apt autoclean
apt autoremove -y

echo
echo -e "${YELLOW}6. Verificando conexão de rede...${NC}"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo -e "${GREEN}Rede OK${NC}"
  echo "Atualizando lista de pacotes..."
  apt update
else
  echo -e "${RED}Sem conexão com internet${NC}"
fi

echo
echo -e "${YELLOW}7. Reiniciando serviços problemáticos...${NC}"
systemctl daemon-reexec
systemctl reset-failed

echo
echo -e "${YELLOW}Serviços com falha:${NC}"
systemctl --failed

echo
echo -e "${YELLOW}8. Corrigindo initramfs...${NC}"
update-initramfs -u

echo
echo -e "${YELLOW}9. Reiniciando stack de áudio...${NC}"
if systemctl --user is-active pipewire >/dev/null 2>&1; then
  systemctl --user restart pipewire pipewire-pulse wireplumber
  echo -e "${GREEN}PipeWire reiniciado${NC}"
elif systemctl --user is-active pulseaudio >/dev/null 2>&1; then
  pulseaudio -k
  echo -e "${GREEN}PulseAudio reiniciado${NC}"
else
  echo -e "${YELLOW}Nenhum stack de áudio ativo${NC}"
fi

echo
echo -e "${YELLOW}10. Garantindo logs persistentes...${NC}"
mkdir -p /var/log/journal
systemctl restart systemd-journald

echo
echo -e "${YELLOW}11. Verificando integridade do sistema de arquivos...${NC}"
touch /forcefsck

echo
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN} Correção concluída${NC}"
echo -e "${GREEN}====================================${NC}"
echo "Reinicie o sistema se os problemas persistirem."