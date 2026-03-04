#!/bin/bash

echo "==============================="
echo " VERIFICAÇÃO DE HARDWARE"
echo "==============================="
echo

# =====================================
# 0. Verificar se smartmontools existe
# =====================================
if command -v smartctl >/dev/null 2>&1; then
    SMART_AVAILABLE=true
    echo "smartmontools detectado."
else
    SMART_AVAILABLE=false
    echo "smartmontools NÃO está instalado."
    echo "Para instalar: sudo apt install smartmontools"
fi
echo

# =====================================
# 1. Discos detectados
# =====================================
echo ">>> 1. Discos detectados (lsblk)"
lsblk -o NAME,SIZE,TYPE,MODEL,TRAN,SERIAL
echo

# =====================================
# 2. Portas SATA
# =====================================
echo ">>> 2. Portas SATA (via /sys)"
for host in /sys/class/ata_host/host*; do
    echo "Controladora: $(basename "$host")"
    cat "$host"/link*/sata_spd 2>/dev/null
done
echo

# =====================================
# 3. Dispositivos SATA/NVMe
# =====================================
echo ">>> 3. Dispositivos SATA/NVMe detectados"
ls /dev/sd* 2>/dev/null
ls /dev/nvme* 2>/dev/null
echo

# =====================================
# 4. Dispositivos PCI
# =====================================
echo ">>> 4. Controladoras de armazenamento (PCI)"
lspci | grep -i -E "sata|ahci|nvme|raid|storage"
echo

# =====================================
# 5. USB
# =====================================
echo ">>> 5. Dispositivos USB"
lsusb
echo

# =====================================
# 6. Erros recentes no kernel
# =====================================
echo ">>> 6. Erros recentes no kernel"
dmesg | grep -i -E "error|fail|sata|nvme|ata|reset" | tail -n 20
echo

# =====================================
# 7. SMART (se disponível)
# =====================================
if [ "$SMART_AVAILABLE" = true ]; then
    echo ">>> 7. Status SMART"
    for disk in /dev/sd?; do
        echo "Verificando $disk"
        sudo smartctl -H "$disk" 2>/dev/null | grep -i "result"
    done
else
    echo ">>> 7. SMART ignorado (smartmontools não instalado)"
fi

echo
echo "Verificação concluída."