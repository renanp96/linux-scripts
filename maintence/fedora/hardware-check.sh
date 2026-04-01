#!/bin/bash
# ================================
# VERIFICAÇÃO DE HARDWARE
# ================================
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
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}
section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

echo -e "${CYAN}===============================${NC}"
echo -e "${CYAN} VERIFICAÇÃO DE HARDWARE${NC}"
echo -e "${CYAN}===============================${NC}"

# =====================================
# 0. Verificar smartmontools
# =====================================
section "Verificação do SMART"
if command -v smartctl >/dev/null 2>&1; then
    SMART_AVAILABLE=true
    log_success "smartmontools detectado"
else
    SMART_AVAILABLE=false
    log_warn "smartmontools NÃO está instalado"
    # Detecta se é sistema imutável (Bazzite/Silverblue) ou Fedora padrão
    if command -v rpm-ostree >/dev/null 2>&1; then
        echo "Instalar com: rpm-ostree install smartmontools"
    else
        echo "Instalar com: sudo dnf install smartmontools"
    fi
fi

# =====================================
# 1. Discos detectados
# =====================================
section "Discos detectados"
lsblk -o NAME,SIZE,TYPE,MODEL,TRAN,SERIAL

# =====================================
# 2. Portas SATA
# =====================================
section "Portas SATA"
if [ -d /sys/class/ata_host ]; then
    for host in /sys/class/ata_host/host*; do
        echo -e "${BLUE}Controladora:${NC} $(basename "$host")"
        cat "$host"/link*/sata_spd 2>/dev/null
    done
else
    log_warn "Nenhuma controladora SATA encontrada"
fi

# =====================================
# 3. Dispositivos SATA/NVMe
# =====================================
section "Dispositivos de armazenamento"
echo -e "${BLUE}SATA:${NC}"
ls /dev/sd* 2>/dev/null || log_warn "Nenhum dispositivo SATA encontrado"
echo
echo -e "${BLUE}NVMe:${NC}"
ls /dev/nvme* 2>/dev/null || log_warn "Nenhum dispositivo NVMe encontrado"

# =====================================
# 4. Controladoras PCI
# =====================================
section "Controladoras de armazenamento (PCI)"
if command -v lspci >/dev/null 2>&1; then
    lspci | grep -i -E "sata|ahci|nvme|raid|storage"
else
    log_warn "lspci não encontrado"
    if command -v rpm-ostree >/dev/null 2>&1; then
        echo "Instalar com: rpm-ostree install pciutils"
    else
        echo "Instalar com: sudo dnf install pciutils"
    fi
fi

# =====================================
# 5. USB
# =====================================
section "Dispositivos USB"
if command -v lsusb >/dev/null 2>&1; then
    lsusb
else
    log_warn "lsusb não encontrado"
    if command -v rpm-ostree >/dev/null 2>&1; then
        echo "Instalar com: rpm-ostree install usbutils"
    else
        echo "Instalar com: sudo dnf install usbutils"
    fi
fi

# =====================================
# 6. Erros recentes do kernel
# =====================================
section "Erros recentes do kernel"
# No Fedora/Bazzite o journalctl é preferível ao dmesg
if command -v journalctl >/dev/null 2>&1; then
    journalctl -k --no-pager | grep -i -E "error|fail|sata|nvme|ata|reset" | tail -n 20
else
    dmesg | grep -i -E "error|fail|sata|nvme|ata|reset" | tail -n 20
fi

# =====================================
# 7. SMART
# =====================================
section "Status SMART"
if [ "$SMART_AVAILABLE" = true ]; then
    for disk in /dev/sd?; do
        echo -e "${BLUE}Verificando $disk${NC}"
        sudo smartctl -H "$disk" 2>/dev/null | grep -i "result"
    done
    # Verifica NVMe também
    for nvme in /dev/nvme?; do
        if [ -e "$nvme" ]; then
            echo -e "${BLUE}Verificando $nvme${NC}"
            sudo smartctl -H "$nvme" 2>/dev/null | grep -i "result"
        fi
    done
else
    log_warn "SMART ignorado (smartmontools não instalado)"
fi

echo
log_success "Verificação de hardware concluída"