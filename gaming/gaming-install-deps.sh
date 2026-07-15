#!/usr/bin/env bash

set -uo pipefail

# ================================
# Auto-elevação
# ================================
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

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
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail() { echo -e "${RED}[FALHA]${NC} $1"; }

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

if [ "$DISTRO_FAMILY" = "unknown" ]; then
    log_fail "Não foi possível detectar a família da distro (sem dnf/apt/pacman/zypper/apk)."
    echo "Abortando para evitar rodar comandos errados no seu sistema."
    exit 1
fi

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} INSTALAÇÃO DO AMBIENTE GAMER ($DISTRO_NAME)${NC}"
echo -e "${CYAN}====================================${NC}"
log_info "Família de distro detectada: $DISTRO_FAMILY"

if [ "$DISTRO_FAMILY" = "alpine" ]; then
    log_warn "Alpine tem suporte MUITO limitado pra gaming: sem multilib oficial,"
    log_warn "gamemode/mangohud geralmente indisponíveis, Steam não empacotado."
    log_warn "O script vai tentar o que for possível e avisar o que não for."
fi

# ================================
# Nomes de pacote por família
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

        rhel-vulkan-drivers)   echo "mesa-vulkan-drivers" ;;
        debian-vulkan-drivers) echo "mesa-vulkan-drivers" ;;
        arch-vulkan-drivers)   echo "vulkan-radeon vulkan-intel" ;;
        suse-vulkan-drivers)   echo "Mesa-vulkan-device-select" ;;
        alpine-vulkan-drivers) echo "mesa-vulkan-ati mesa-vulkan-intel" ;;

        rhel-wine)     echo "wine" ;;
        debian-wine)   echo "wine" ;;
        arch-wine)     echo "wine" ;;
        suse-wine)     echo "wine" ;;
        alpine-wine)   echo "wine" ;;

        rhel-winetricks)   echo "winetricks" ;;
        debian-winetricks) echo "winetricks" ;;
        arch-winetricks)   echo "winetricks" ;;
        suse-winetricks)   echo "winetricks" ;;
        alpine-winetricks) echo "winetricks" ;;

        rhel-gamemode)   echo "gamemode" ;;
        debian-gamemode) echo "gamemode" ;;
        arch-gamemode)   echo "gamemode" ;;
        suse-gamemode)   echo "gamemoded" ;;
        alpine-gamemode) echo "gamemode" ;;

        rhel-mangohud)   echo "mangohud" ;;
        debian-mangohud) echo "mangohud" ;;
        arch-mangohud)   echo "mangohud" ;;
        suse-mangohud)   echo "mangohud" ;;
        alpine-mangohud) echo "mangohud" ;;

        rhel-flatpak)   echo "flatpak" ;;
        debian-flatpak) echo "flatpak" ;;
        arch-flatpak)   echo "flatpak" ;;
        suse-flatpak)   echo "flatpak" ;;
        alpine-flatpak) echo "flatpak" ;;

        *) echo "$key" ;;
    esac
}

# Pacotes principais (nomes lógicos — traduzidos por pkg_name)
PACKAGE_KEYS=(
    wine
    winetricks
    gamemode
    mangohud
    vulkan-tools
    vulkan-drivers
    mesa-demos
)

# ================================
# Wrappers por família: update / install / is_installed
# ================================
update_system() {
    case "$DISTRO_FAMILY" in
        rhel)   dnf upgrade -y ;;
        debian) apt update && apt upgrade -y ;;
        arch)   pacman -Syu --noconfirm ;;
        suse)   zypper --non-interactive refresh && zypper --non-interactive update ;;
        alpine) apk update && apk upgrade ;;
    esac
}

is_pkg_installed() {
    local pkg="$1"
    case "$DISTRO_FAMILY" in
        rhel|suse) rpm -q "$pkg" >/dev/null 2>&1 ;;
        debian)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        arch)      pacman -Qi "$pkg" >/dev/null 2>&1 ;;
        alpine)    apk info -e "$pkg" >/dev/null 2>&1 ;;
    esac
}

install_pkg() {
    # Aceita múltiplos nomes de pacote (ex: "vulkan-radeon vulkan-intel")
    local pkgs="$1"
    case "$DISTRO_FAMILY" in
        rhel)   dnf install -y $pkgs ;;
        debian) apt install -y $pkgs ;;
        arch)   pacman -S --noconfirm --needed $pkgs ;;
        suse)   zypper --non-interactive install $pkgs ;;
        alpine) apk add $pkgs ;;
    esac
}

# Instala uma "chave lógica" de pacote, com log e tratamento de erro por item
install_by_key() {
    local key="$1"
    local pkg
    pkg=$(pkg_name "$key")

    if is_pkg_installed "$pkg"; then
        log_warn "$pkg já está instalado"
        return 0
    fi

    log_info "Instalando $pkg"
    if install_pkg "$pkg"; then
        log_ok "$pkg instalado"
    else
        log_fail "Falha ao instalar $pkg (pode não existir nos repositórios habilitados nesta distro/versão)"
    fi
}

# =====================================
# 1. Atualizar sistema
# =====================================
section "Atualizando sistema"
update_system || log_warn "Atualização do sistema retornou erro — continuando mesmo assim"

# =====================================
# 2. Repositório de drivers/codecs não-livres
# =====================================
section "Configurando repositórios extras"

case "$DISTRO_FAMILY" in
    rhel)
        if dnf repolist 2>/dev/null | grep -q rpmfusion; then
            log_warn "RPM Fusion já configurado"
        else
            log_info "Instalando RPM Fusion"
            if dnf install -y \
                "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"; then
                log_ok "RPM Fusion instalado"
            else
                log_fail "Falha ao instalar RPM Fusion — drivers NVIDIA e alguns codecs não estarão disponíveis"
            fi
        fi
        ;;
    debian)
        if [ "$DISTRO_ID" = "ubuntu" ]; then
            if apt-cache policy 2>/dev/null | grep -qi multiverse; then
                log_warn "Componente multiverse já parece habilitado"
            else
                log_info "Habilitando componente multiverse (Ubuntu)"
                if ! command -v add-apt-repository >/dev/null 2>&1; then
                    apt install -y software-properties-common
                fi
                if add-apt-repository -y multiverse && apt update; then
                    log_ok "Multiverse habilitado"
                else
                    log_fail "Falha ao habilitar multiverse — habilite manualmente em /etc/apt/sources.list"
                fi
            fi
        else
            # Debian puro: formato de sources.list varia bastante entre versões
            # (clássico vs deb822 a partir do Debian 12). Editar automaticamente
            # é arriscado, então só detectamos e instruímos.
            if grep -Eq "non-free-firmware|non-free" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
                log_warn "Componente non-free/non-free-firmware já parece habilitado"
            else
                log_warn "Componente non-free-firmware não detectado"
                echo "Adicione manualmente 'non-free-firmware' (Debian 12+) ou 'non-free' (Debian <=11)"
                echo "às linhas 'deb' em /etc/apt/sources.list e rode: sudo apt update"
            fi
        fi
        ;;
    arch)
        if pacman -Sl multilib >/dev/null 2>&1; then
            log_warn "Repositório multilib já habilitado"
        else
            log_info "Habilitando repositório [multilib] em /etc/pacman.conf"
            cp /etc/pacman.conf /etc/pacman.conf.bak."$(date +%s)"
            # Descomenta o bloco padrão:
            #   #[multilib]
            #   #Include = /etc/pacman.d/mirrorlist
            if sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf \
               && pacman -Sy --noconfirm; then
                log_ok "Multilib habilitado (backup do pacman.conf salvo)"
            else
                log_fail "Falha ao habilitar multilib automaticamente — edite /etc/pacman.conf manualmente"
            fi
        fi
        ;;
    suse)
        if zypper repos 2>/dev/null | grep -qi packman; then
            log_warn "Repositório Packman já configurado"
        else
            log_warn "Repositório Packman não configurado (recomendado, mas não essencial pra 32-bit no openSUSE)"
            echo "Veja: https://en.opensuse.org/Additional_package_repositories#Packman"
        fi
        ;;
    alpine)
        log_info "Alpine não tem um equivalente a RPM Fusion/multiverse — pulando"
        ;;
esac

# =====================================
# 3. Instalar pacotes principais
# =====================================
section "Instalando ferramentas"

for key in "${PACKAGE_KEYS[@]}"; do
    install_by_key "$key"
done

# =====================================
# 4. Suporte 32-bit (multilib)
# =====================================
section "Configurando suporte 32-bit"

case "$DISTRO_FAMILY" in
    rhel)
        for pkg in mesa-libGL.i686 mesa-libGLU.i686 mesa-vulkan-drivers.i686; do
            if is_pkg_installed "$pkg"; then
                log_warn "$pkg já instalado"
            else
                log_info "Instalando $pkg"
                install_pkg "$pkg" && log_ok "$pkg instalado" || log_fail "Falha ao instalar $pkg"
            fi
        done
        ;;
    suse)
        for pkg in Mesa-libGL1-32bit libvulkan1-32bit; do
            if is_pkg_installed "$pkg"; then
                log_warn "$pkg já instalado"
            else
                log_info "Instalando $pkg"
                install_pkg "$pkg" && log_ok "$pkg instalado" || log_fail "Falha ao instalar $pkg"
            fi
        done
        ;;
    debian)
        if dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
            log_warn "Arquitetura i386 já habilitada"
        else
            log_info "Habilitando arquitetura i386"
            dpkg --add-architecture i386 && apt update
        fi
        for pkg in libgl1:i386 libglu1-mesa:i386; do
            if is_pkg_installed "$pkg"; then
                log_warn "$pkg já instalado"
            else
                log_info "Instalando $pkg"
                install_pkg "$pkg" && log_ok "$pkg instalado" || log_fail "Falha ao instalar $pkg"
            fi
        done
        ;;
    arch)
        for pkg in lib32-mesa lib32-vulkan-icd-loader; do
            if is_pkg_installed "$pkg"; then
                log_warn "$pkg já instalado"
            else
                log_info "Instalando $pkg"
                install_pkg "$pkg" && log_ok "$pkg instalado" || log_fail "Falha ao instalar $pkg (confirme que [multilib] foi habilitado acima)"
            fi
        done
        ;;
    alpine)
        log_warn "Alpine não oferece multilib oficial — suporte 32-bit não configurado"
        ;;
esac

# =====================================
# 5. Steam via Flatpak (multi-distro)
# =====================================
section "Instalando Steam (Flatpak)"

if [ "$DISTRO_FAMILY" = "alpine" ]; then
    log_warn "Flatpak/Steam raramente funcionam bem no Alpine (musl) — pulando esta etapa"
else
    if ! command -v flatpak >/dev/null 2>&1; then
        log_info "Instalando Flatpak"
        install_pkg "$(pkg_name flatpak)"
    fi

    if command -v flatpak >/dev/null 2>&1; then
        if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
            log_info "Adicionando Flathub"
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        fi

        if flatpak list 2>/dev/null | grep -q com.valvesoftware.Steam; then
            log_warn "Steam já instalado via Flatpak"
        else
            log_info "Instalando Steam"
            if flatpak install -y flathub com.valvesoftware.Steam; then
                log_ok "Steam instalado"
            else
                log_fail "Falha ao instalar Steam via Flatpak"
            fi
        fi
    else
        log_fail "Flatpak não pôde ser instalado — pulando Steam"
    fi
fi

# =====================================
# 6. Verificação final
# =====================================
section "Verificação final"

for key in "${PACKAGE_KEYS[@]}"; do
    pkg=$(pkg_name "$key")
    if is_pkg_installed "$pkg"; then
        log_ok "$pkg"
    else
        log_fail "$pkg"
    fi
done

echo
log_ok "Ambiente gamer pronto ($DISTRO_NAME)"