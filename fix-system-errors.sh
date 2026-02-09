#!/bin/bash

# Auto-elevacao para root
if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

echo "== Correcao automatica basica do sistema =="

echo
echo "1. Corrigindo pacotes quebrados..."
apt --fix-broken install -y

echo
echo "2. Reconfigurando pacotes pendentes..."
dpkg --configure -a

echo
echo "3. Limpando cache APT..."
apt clean
apt autoclean
apt autoremove -y

echo
echo "4. Atualizando lista de pacotes..."
apt update

echo
echo "5. Reiniciando servicos problemáticos..."
systemctl daemon-reexec
systemctl reset-failed

echo
echo "6. Corrigindo initramfs..."
update-initramfs -u

echo
echo "7. Reiniciando stack de audio..."
if systemctl --user is-active pipewire >/dev/null 2>&1; then
  systemctl --user restart pipewire pipewire-pulse wireplumber
  echo "PipeWire reiniciado"
elif systemctl --user is-active pulseaudio >/dev/null 2>&1; then
  pulseaudio -k
  echo "PulseAudio reiniciado"
else
  echo "Nenhum stack de audio ativo"
fi

echo
echo "8. Garantindo logs persistentes..."
mkdir -p /var/log/journal
systemctl restart systemd-journald

echo
echo "== Correcao concluida =="
echo "Reinicie o sistema se problemas persistirem."

