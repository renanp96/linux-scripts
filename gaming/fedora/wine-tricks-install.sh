#!/usr/bin/env bash
set -e

# ================================
# PREPARAÇÃO WINE PARA JOGOS - FEDORA
# ================================

# Auto-elevação
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Usuário real (importante no Fedora)
REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(eval echo "~$REAL_USER")

# Prefixo dedicado
export WINEPREFIX="$REAL_HOME/.wine-gaming"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================================
# Funções
# ================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

section() {
    echo
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
}

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN} CONFIGURAÇÃO DO WINE PARA JOGOS (FEDORA)${NC}"
echo -e "${CYAN}====================================${NC}"

# =====================================
# 1. RPM Fusion (necessário pro Wine completo)
# =====================================
section "RPM Fusion"

if dnf repolist | grep -q rpmfusion; then
    log_warn "RPM Fusion já configurado"
else
    log_info "Instalando RPM Fusion"
    dnf install -y \
        https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    log_ok "RPM Fusion instalado"
fi

# =====================================
# 2. Atualizar sistema
# =====================================
section "Atualizando sistema"

dnf upgrade -y

# =====================================
# 3. Instalar Wine + dependências
# =====================================
section "Instalando Wine"

dnf install -y \
    wine \
    winetricks \
    mesa-dri-drivers \
    mesa-libGL \
    mesa-libGLU \
    mesa-vulkan-drivers

log_ok "Wine instalado"

# =====================================
# 4. Multilib (ESSENCIAL)
# =====================================
section "Suporte 32-bit"

dnf install -y \
    mesa-libGL.i686 \
    mesa-libGLU.i686 \
    mesa-vulkan-drivers.i686

log_ok "Multilib configurado"

# =====================================
# 5. Criar prefixo Wine
# =====================================
section "Criando prefixo Wine"

if [ -d "$WINEPREFIX" ]; then
    log_warn "Prefixo já existe: $WINEPREFIX"
else
    log_info "Criando prefixo limpo"
    sudo -u "$REAL_USER" WINEPREFIX="$WINEPREFIX" wineboot --init
    log_ok "Prefixo criado em $WINEPREFIX"
fi

# =====================================
# 6. Instalar bibliotecas essenciais
# =====================================
section "Instalando libs de jogos"

log_info "Instalando dependências (isso pode demorar)"

sudo -u "$REAL_USER" WINEPREFIX="$WINEPREFIX" winetricks -q \
    corefonts \
    vcrun2015 vcrun2017 vcrun2019 vcrun2022 \
    d3dx9 d3dx10 d3dx11 \
    dxvk \
    dotnet48 || log_warn "Algumas libs podem falhar (normal)"

# =====================================
# 7. Permissões (evita bugs comuns)
# =====================================
section "Ajustando permissões"

chown -R "$REAL_USER":"$REAL_USER" "$WINEPREFIX"

log_ok "Permissões ajustadas"

# =====================================
# 8. Verificação final
# =====================================
section "Verificação"

if command -v wine >/dev/null 2>&1; then
    sudo -u "$REAL_USER" wine --version
    log_ok "Wine funcionando"
else
    echo -e "${RED}[FAIL] Wine não encontrado${NC}"
fi

echo
log_ok "Wine pronto para jogos no Fedora"
echo
echo "Prefixo:"
echo "  $WINEPREFIX"
echo
echo "Comandos úteis:"
echo "  WINEPREFIX=$WINEPREFIX winecfg"
echo "  WINEPREFIX=$WINEPREFIX winetricks"
echo "  WINEPREFIX=$WINEPREFIX wine jogo.exe"