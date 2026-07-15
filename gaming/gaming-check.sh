#!/usr/bin/env bash
set -o pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================================
# Funções de log
# ================================
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

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

# ================================
# Mapa de nomes de pacote por família
# (chave lógica -> nome real do pacote na distro)
# ================================
pkg_name() {
    local key="$1"
    case "$DISTRO_FAMILY-$key" in
        rhel-mesa-demos)     echo "mesa-demos" ;;
        debian-mesa-demos)   echo "mesa-utils" ;;
        arch-mesa-demos)     echo "mesa-demos" ;;
        suse-mesa-demos)     echo "Mesa-demo-x" ;;
        alpine-mesa-demos)   echo "mesa-demos" ;;

        rhel-vulkan-tools)   echo "vulkan-tools" ;;
        debian-vulkan-tools) echo "vulkan-tools" ;;
        arch-vulkan-tools)   echo "vulkan-tools" ;;
        suse-vulkan-tools)   echo "vulkan-tools" ;;
        alpine-vulkan-tools) echo "vulkan-tools" ;;

        rhel-nvidia)         echo "akmod-nvidia (via RPM Fusion)" ;;
        debian-nvidia)       echo "nvidia-driver" ;;
        arch-nvidia)         echo "nvidia nvidia-utils" ;;
        suse-nvidia)         echo "x11-video-nvidiaG06 (via Packman/NVIDIA repo)" ;;
        alpine-nvidia)       echo "nvidia (suporte limitado no Alpine)" ;;

        rhel-wine)           echo "wine" ;;
        debian-wine)         echo "wine" ;;
        arch-wine)           echo "wine" ;;
        suse-wine)           echo "wine" ;;
        alpine-wine)         echo "wine" ;;

        rhel-winetricks)     echo "winetricks" ;;
        debian-winetricks)   echo "winetricks" ;;
        arch-winetricks)     echo "winetricks" ;;
        suse-winetricks)     echo "winetricks" ;;
        alpine-winetricks)   echo "winetricks" ;;

        rhel-lutris)         echo "lutris" ;;
        debian-lutris)       echo "lutris" ;;
        arch-lutris)         echo "lutris" ;;
        suse-lutris)         echo "lutris" ;;
        alpine-lutris)       echo "lutris" ;;

        rhel-steam)          echo "steam" ;;
        debian-steam)        echo "steam" ;;
        arch-steam)          echo "steam" ;;
        suse-steam)          echo "steam" ;;
        alpine-steam)        echo "steam (não empacotado oficialmente — use Flatpak)" ;;

        *) echo "$key" ;;
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

# Checa se um pacote está instalado, usando o mecanismo nativo de cada família
is_pkg_installed() {
    local key="$1"
    local pkg
    pkg=$(pkg_name "$key")
    case "$DISTRO_FAMILY" in
        rhel|suse) rpm -q "$pkg" >/dev/null 2>&1 ;;
        debian)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        arch)      pacman -Qi "$pkg" >/dev/null 2>&1 ;;
        alpine)    apk info -e "$pkg" >/dev/null 2>&1 ;;
        *)         return 1 ;;
    esac
}

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} GAMING ENVIRONMENT CHECK ($DISTRO_NAME)${NC}"
echo -e "${CYAN}====================================${NC}"
log_info "Família de distro detectada: $DISTRO_FAMILY"

# =====================================
# 1. Ferramentas básicas
# =====================================
section "Ferramentas de jogo"

# Steam (pacote nativo ou Flatpak)
STEAM_FOUND=false
command -v steam >/dev/null 2>&1 && STEAM_FOUND=true
if ! $STEAM_FOUND && command -v flatpak >/dev/null 2>&1; then
    flatpak list 2>/dev/null | grep -q com.valvesoftware.Steam && STEAM_FOUND=true
fi
if $STEAM_FOUND; then
    log_ok "Steam instalado"
else
    log_warn "Steam não instalado ($(pkg_install_hint steam) ou via Flatpak: flatpak install flathub com.valvesoftware.Steam)"
fi

# Wine
if command -v wine >/dev/null 2>&1; then
    log_ok "Wine instalado"
else
    log_warn "Wine não instalado ($(pkg_install_hint wine))"
fi

# Winetricks
if command -v winetricks >/dev/null 2>&1; then
    log_ok "Winetricks instalado"
else
    log_warn "Winetricks não instalado ($(pkg_install_hint winetricks))"
fi

# Lutris
if command -v lutris >/dev/null 2>&1; then
    log_ok "Lutris instalado"
else
    log_warn "Lutris não instalado ($(pkg_install_hint lutris))"
fi

# =====================================
# 2. GPU
# =====================================
section "GPU detectada"

if command -v lspci >/dev/null 2>&1; then
    GPU=$(lspci | grep -E "VGA|3D")
    if [ -n "$GPU" ]; then
        echo "$GPU"
    else
        log_fail "Nenhuma GPU detectada"
    fi
else
    log_warn "'lspci' não encontrado ($(pkg_install_hint pciutils 2>/dev/null || echo "instale pciutils"))"
fi

# =====================================
# 3. Driver NVIDIA
# =====================================
section "Driver NVIDIA"

if command -v nvidia-smi >/dev/null 2>&1; then
    log_ok "Driver NVIDIA ativo"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    log_warn "Driver NVIDIA não detectado"
    case "$DISTRO_FAMILY" in
        rhel)
            echo "Dica: habilite o RPM Fusion e rode: sudo dnf install akmod-nvidia"
            ;;
        debian)
            echo "Dica: habilite o componente 'non-free'/'non-free-firmware' e rode: sudo apt install nvidia-driver"
            ;;
        arch)
            echo "Dica: sudo pacman -S nvidia nvidia-utils (ou nvidia-dkms em kernels não-padrão)"
            ;;
        suse)
            echo "Dica: adicione o repositório NVIDIA/Packman e rode: sudo zypper install x11-video-nvidiaG06"
            ;;
        alpine)
            echo "Suporte a NVIDIA no Alpine é limitado — verifique a wiki da distro"
            ;;
        *)
            echo "Consulte a documentação da sua distro para instalar o driver NVIDIA"
            ;;
    esac
fi

# =====================================
# 4. OpenGL (Mesa)
# =====================================
section "OpenGL"

if command -v glxinfo >/dev/null 2>&1; then
    glxinfo | grep "OpenGL renderer"
else
    log_warn "Ferramentas Mesa (glxinfo) não instaladas"
    echo "Instale com: $(pkg_install_hint mesa-demos)"
fi

# =====================================
# 5. Vulkan
# =====================================
section "Vulkan"

if command -v vulkaninfo >/dev/null 2>&1; then
    if vulkaninfo >/dev/null 2>&1; then
        log_ok "Vulkan funcionando"
    else
        log_fail "Vulkan instalado mas com erro"
    fi
else
    log_warn "Vulkan não instalado"
    echo "Instale com: $(pkg_install_hint vulkan-tools)"
fi

# =====================================
# 6. Bibliotecas 32-bit (importante pro Steam)
# =====================================
section "Suporte 32-bit (multilib)"

case "$DISTRO_FAMILY" in
    rhel)
        if rpm -qa | grep -q "mesa-libGL.i686"; then
            log_ok "Bibliotecas 32-bit instaladas"
        else
            log_warn "Faltando libs 32-bit"
            echo "Instale com: sudo dnf install mesa-libGL.i686 mesa-libGLU.i686"
        fi
        ;;
    suse)
        if rpm -qa | grep -qi "Mesa-libGL.*-32bit"; then
            log_ok "Bibliotecas 32-bit instaladas"
        else
            log_warn "Faltando libs 32-bit"
            echo "Instale com: sudo zypper install Mesa-libGL1-32bit"
        fi
        ;;
    debian)
        if dpkg --print-foreign-architectures 2>/dev/null | grep -q i386 \
           && dpkg -s libgl1:i386 >/dev/null 2>&1; then
            log_ok "Bibliotecas 32-bit instaladas"
        else
            log_warn "Faltando arquitetura/libs 32-bit"
            echo "Instale com:"
            echo "  sudo dpkg --add-architecture i386"
            echo "  sudo apt update && sudo apt install libgl1:i386"
        fi
        ;;
    arch)
        if pacman -Qq lib32-mesa >/dev/null 2>&1; then
            log_ok "Bibliotecas 32-bit instaladas"
        else
            log_warn "Faltando libs 32-bit (repositório multilib)"
            echo "Habilite [multilib] em /etc/pacman.conf e rode: sudo pacman -S lib32-mesa"
        fi
        ;;
    alpine)
        log_warn "Suporte multilib/32-bit não é padrão no Alpine — geralmente não aplicável"
        ;;
    *)
        log_warn "Checagem de libs 32-bit não implementada para esta distro"
        ;;
esac

# =====================================
# 7. Repositórios extras (drivers/codecs não-livres)
# =====================================
section "Repositórios de terceiros / não-livres"

case "$DISTRO_FAMILY" in
    rhel)
        if command -v dnf >/dev/null 2>&1 && dnf repolist 2>/dev/null | grep -qi rpmfusion; then
            log_ok "RPM Fusion configurado"
        else
            log_warn "RPM Fusion não configurado"
            echo "Instale com:"
            echo "sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm"
            echo "sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm"
        fi
        ;;
    debian)
        if command -v apt-cache >/dev/null 2>&1 && apt-cache policy 2>/dev/null | grep -qiE "non-free|multiverse"; then
            log_ok "Componente non-free/multiverse parece habilitado"
        else
            log_warn "Componente non-free (Debian) ou multiverse (Ubuntu) não detectado"
            echo "Edite /etc/apt/sources.list (Debian: adicione 'non-free non-free-firmware';"
            echo "Ubuntu: adicione 'multiverse') e rode: sudo apt update"
        fi
        ;;
    arch)
        if pacman -Sl multilib >/dev/null 2>&1; then
            log_ok "Repositório multilib habilitado"
        else
            log_warn "Repositório multilib não habilitado"
            echo "Descomente [multilib] em /etc/pacman.conf e rode: sudo pacman -Sy"
        fi
        ;;
    suse)
        if command -v zypper >/dev/null 2>&1 && zypper repos 2>/dev/null | grep -qi packman; then
            log_ok "Repositório Packman configurado"
        else
            log_warn "Repositório Packman não configurado (recomendado para codecs/drivers)"
            echo "Veja: https://en.opensuse.org/Additional_package_repositories#Packman"
        fi
        ;;
    alpine)
        log_info "Alpine usa 'community'/'testing' — confira /etc/apk/repositories"
        ;;
    *)
        log_warn "Checagem de repositórios extras não implementada para esta distro"
        ;;
esac

echo
echo -e "${GREEN}Verificação gamer concluída ($DISTRO_NAME).${NC}"