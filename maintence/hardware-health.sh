#!/usr/bin/env bash
# ============================================
#   DIAGNÓSTICO DE SAÚDE DE HARDWARE
#   Multi-distro — somente leitura (não corrige nada)
# ============================================
set -uo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================================
# Funções de log
# ================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail()    { echo -e "${RED}[FAIL]${NC} $1"; }

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

HAS_SYSTEMD=false
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi

IS_ROOT=false
[ "$EUID" -eq 0 ] && IS_ROOT=true

# ================================
# Nomes de pacote por família
# ================================
pkg_name() {
    local key="$1"
    case "$DISTRO_FAMILY-$key" in
        rhel-lm-sensors)   echo "lm_sensors" ;;
        debian-lm-sensors) echo "lm-sensors" ;;
        arch-lm-sensors)   echo "lm_sensors" ;;
        suse-lm-sensors)   echo "sensors" ;;
        alpine-lm-sensors) echo "lm-sensors" ;;
        *) echo "$key" ;;   # smartmontools, usbutils, pciutils, dmidecode, ethtool: mesmo nome nas 5 famílias
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
echo -e "${CYAN} DIAGNÓSTICO DE SAÚDE DE HARDWARE ($DISTRO_NAME)${NC}"
echo -e "${CYAN}====================================${NC}"
log_info "Família: $DISTRO_FAMILY | systemd: $HAS_SYSTEMD | root: $IS_ROOT"
$IS_ROOT || log_warn "Rodando sem root — algumas checagens (dmidecode, SMART em certos discos, EDAC) podem ficar incompletas"

# =====================================
# 1. CPU
# =====================================
section "CPU"
if command -v lscpu >/dev/null 2>&1; then
    lscpu | grep -E "Model name|Socket|Core|Thread|MHz|Architecture" 
else
    log_warn "'lscpu' não encontrado ($(pkg_install_hint util-linux))"
    grep "model name" /proc/cpuinfo 2>/dev/null | head -1
fi
echo "Núcleos lógicos: $(nproc 2>/dev/null || echo desconhecido)"

# =====================================
# 2. Memória (RAM)
# =====================================
section "Memória (RAM)"
free -h 2>/dev/null || log_warn "'free' não encontrado ($(pkg_install_hint procps))"

if $IS_ROOT && command -v dmidecode >/dev/null 2>&1; then
    echo
    echo "Módulos instalados (dmidecode):"
    dmidecode -t 17 2>/dev/null | grep -E "Locator:|Size:|Speed:|Manufacturer:" | grep -v "No Module Installed" | sed 's/^/  /'
elif ! command -v dmidecode >/dev/null 2>&1; then
    log_warn "'dmidecode' não encontrado ($(pkg_install_hint dmidecode)) — detalhes de DIMM pulados"
else
    log_warn "dmidecode requer root — detalhes de DIMM pulados"
fi

# =====================================
# 3. Erros de memória (EDAC / MCE)
# =====================================
section "Erros de memória (EDAC/ECC)"
EDAC_FOUND=false
for mc in /sys/devices/system/edac/mc/mc*/; do
    [ -d "$mc" ] || continue
    EDAC_FOUND=true
    CE=$(cat "${mc}ce_count" 2>/dev/null || echo "?")
    UE=$(cat "${mc}ue_count" 2>/dev/null || echo "?")
    if [ "$UE" != "0" ] && [ "$UE" != "?" ]; then
        log_fail "$(basename "$mc"): erros NÃO corrigíveis (UE) = $UE, corrigíveis (CE) = $CE"
    elif [ "$CE" != "0" ] && [ "$CE" != "?" ]; then
        log_warn "$(basename "$mc"): erros corrigíveis (CE) = $CE (nenhum erro fatal, mas vale observar)"
    else
        log_ok "$(basename "$mc"): sem erros ECC registrados"
    fi
done
$EDAC_FOUND || log_info "EDAC não disponível (sem suporte a ECC, ou módulo não carregado)"

# =====================================
# 4. Espaço em disco
# =====================================
section "Espaço em disco (>=80% é alerta)"
df -h -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR==1 || $5+0 >= 80'

# =====================================
# 5. Saúde dos discos (SMART)
# =====================================
section "Saúde dos discos (SMART)"
if command -v smartctl >/dev/null 2>&1; then
    DISKS_FOUND=false
    for disk in /dev/sd? /dev/nvme?n1 /dev/vd?; do
        [ -e "$disk" ] || continue
        DISKS_FOUND=true
        HEALTH=$(smartctl -H "$disk" 2>/dev/null | grep -iE "overall-health|SMART Health Status" | head -1)
        if echo "$HEALTH" | grep -qi "PASSED\|OK"; then
            log_ok "$disk: $HEALTH"
        elif [ -n "$HEALTH" ]; then
            log_fail "$disk: $HEALTH"
        else
            log_warn "$disk: não foi possível ler status SMART (permissão? disco USB sem suporte?)"
        fi
        # Atributos relevantes quando disponíveis (HDD/SSD SATA)
        smartctl -A "$disk" 2>/dev/null | grep -E "Reallocated_Sector|Reallocated_Event|Power_On_Hours|Temperature_Celsius|Media_Wearout|Wear_Leveling" | sed 's/^/    /'
        # NVMe usa um formato de log diferente
        smartctl -A "$disk" 2>/dev/null | grep -E "Temperature:|Percentage Used:|Media and Data Integrity Errors" | sed 's/^/    /'
    done
    $DISKS_FOUND || log_info "Nenhum disco /dev/sd?, /dev/nvme?n1 ou /dev/vd? encontrado"
else
    log_warn "smartmontools não instalado ($(pkg_install_hint smartmontools)) — pulando checagem SMART"
fi

# =====================================
# 6. GPU
# =====================================
section "GPU"
if command -v lspci >/dev/null 2>&1; then
    lspci | grep -E "VGA|3D" | sed 's/^/  /'
else
    log_warn "'lspci' não encontrado ($(pkg_install_hint pciutils))"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
    echo
    log_info "NVIDIA detectada:"
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,ecc.errors.uncorrected.aggregate.total \
        --format=csv,noheader 2>/dev/null | sed 's/^/  /'
elif command -v rocm-smi >/dev/null 2>&1; then
    echo
    log_info "AMD (ROCm) detectada:"
    rocm-smi --showtemp --showuse 2>/dev/null | sed 's/^/  /'
fi

# =====================================
# 7. Temperatura / Sensores
# =====================================
section "Temperatura / Sensores"
if command -v sensors >/dev/null 2>&1; then
    sensors 2>/dev/null
else
    log_warn "lm-sensors não instalado ($(pkg_install_hint lm-sensors))"
    # Fallback via sysfs — funciona mesmo sem lm-sensors configurado
    FOUND_ZONE=false
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$zone" ] || continue
        FOUND_ZONE=true
        TEMP_RAW=$(cat "$zone" 2>/dev/null)
        [ -n "$TEMP_RAW" ] && printf "  %s: %.1f°C\n" "$(dirname "$zone")" "$(echo "$TEMP_RAW / 1000" | bc -l 2>/dev/null || echo "$((TEMP_RAW / 1000))")"
    done
    $FOUND_ZONE || log_info "Nenhuma thermal zone encontrada em /sys/class/thermal"
fi

# =====================================
# 8. Bateria (notebooks)
# =====================================
section "Bateria"
BATTERY_FOUND=false
for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    BATTERY_FOUND=true
    NAME=$(basename "$bat")
    STATUS=$(cat "$bat/status" 2>/dev/null || echo "?")
    CAPACITY=$(cat "$bat/capacity" 2>/dev/null || echo "?")

    FULL_NOW=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null || echo "")
    FULL_DESIGN=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null || echo "")
    CYCLES=$(cat "$bat/cycle_count" 2>/dev/null || echo "")

    echo "  $NAME — status: $STATUS, carga atual: ${CAPACITY}%"
    if [ -n "$FULL_NOW" ] && [ -n "$FULL_DESIGN" ] && [ "$FULL_DESIGN" -gt 0 ] 2>/dev/null; then
        HEALTH=$(( FULL_NOW * 100 / FULL_DESIGN ))
        if [ "$HEALTH" -ge 80 ]; then
            log_ok "$NAME: saúde da bateria ~${HEALTH}% da capacidade original"
        else
            log_warn "$NAME: saúde da bateria ~${HEALTH}% da capacidade original (degradação significativa)"
        fi
    fi
    [ -n "$CYCLES" ] && [ "$CYCLES" != "0" ] && echo "    Ciclos de carga: $CYCLES"
done
$BATTERY_FOUND || log_info "Nenhuma bateria detectada (desktop, ou sysfs sem /sys/class/power_supply/BAT*)"

# =====================================
# 9. Dispositivos USB
# =====================================
section "Dispositivos USB"
if command -v lsusb >/dev/null 2>&1; then
    lsusb | sed 's/^/  /'
else
    log_warn "'lsusb' não encontrado ($(pkg_install_hint usbutils))"
fi

# =====================================
# 10. Interfaces de rede
# =====================================
section "Interfaces de rede"
if command -v ip >/dev/null 2>&1; then
    ip -brief link show 2>/dev/null | sed 's/^/  /'
    echo
    if command -v ethtool >/dev/null 2>&1; then
        for iface in $(ip -brief link show 2>/dev/null | awk '{print $1}' | grep -v '^lo$'); do
            LINK=$(ethtool "$iface" 2>/dev/null | grep -i "Link detected")
            [ -n "$LINK" ] && echo "  $iface: $LINK"
        done
    else
        log_warn "'ethtool' não encontrado ($(pkg_install_hint ethtool)) — status de link detalhado pulado"
    fi
else
    log_warn "'ip' (iproute2) não encontrado"
fi

# =====================================
# 11. Erros de hardware no kernel (dmesg)
# =====================================
section "Erros de hardware recentes no kernel"
HW_ERRORS=""
if $HAS_SYSTEMD && command -v journalctl >/dev/null 2>&1; then
    HW_ERRORS=$(journalctl -k -p err -b --no-pager 2>/dev/null | grep -iE "error|fail|corrupt|mce|i/o error" | tail -20)
elif command -v dmesg >/dev/null 2>&1; then
    HW_ERRORS=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | tail -20)
fi

if [ -z "$HW_ERRORS" ]; then
    log_ok "Nenhum erro crítico de hardware encontrado nos logs do kernel"
else
    log_warn "Mensagens de erro encontradas nos logs do kernel:"
    echo "$HW_ERRORS" | sed 's/^/  /'
fi

# =====================================
# 12. Taint flags do kernel
# =====================================
section "Taint flags do kernel"
if [ -r /proc/sys/kernel/tainted ]; then
    TAINT=$(cat /proc/sys/kernel/tainted)
    if [ "$TAINT" -eq 0 ]; then
        log_ok "Kernel não contaminado (tainted=0)"
    else
        log_warn "Kernel contaminado (tainted=$TAINT) — geralmente indica módulo proprietário/fora da árvore"
        echo "  Ex.: driver NVIDIA proprietário, módulos DKMS, ou firmware/hardware reportando erro grave"
        echo "  Detalhes: https://www.kernel.org/doc/html/latest/admin-guide/tainted-kernels.html"
    fi
else
    log_warn "/proc/sys/kernel/tainted não legível"
fi

echo
log_ok "Diagnóstico de hardware concluído ($DISTRO_NAME)"