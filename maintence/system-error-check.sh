#!/bin/bash
echo "== Diagnóstico rápido do sistema =="

echo
echo "1. Espaço em disco (>=80% é alerta):"
df -h -x tmpfs -x devtmpfs | awk 'NR==1 || $5+0 >= 80'

echo
echo "2. Memória:"
free -h

echo
echo "3. CPU / Load:"
uptime

echo
echo "4. Temperatura (se disponível):"
sensors 2>/dev/null || echo "lm-sensors não instalado"

echo
echo "5. Serviços com falha:"
systemctl --failed --no-pager || echo "Nenhum serviço falhou"

echo
echo "6. Erros críticos do boot atual:"
journalctl -p 3 -b --no-pager | tail -20 || echo "Nenhum erro crítico"

echo
echo "7. Erros do boot anterior:"
journalctl -p 3 -b -1 --no-pager | tail -20 || echo "Sem logs persistentes"

echo
echo "8. Pacotes quebrados:"
dpkg -l | grep -E "^..r|^..U|^..iF" || echo "Nenhum pacote quebrado"

echo
echo "9. Docker (se usado):"
docker ps --format "  - {{.Names}} ({{.Status}})" 2>/dev/null || echo "Docker não ativo"

echo
echo "10. GPU NVIDIA (se existir):"
nvidia-smi 2>/dev/null || echo "Driver NVIDIA não carregado"

echo
echo "11. Áudio (Pulse / PipeWire):"
pactl info 2>/dev/null | grep -E "Server Name|Default Sink" || echo "Audio stack não encontrado"

echo
echo "== Diagnóstico concluído =="
