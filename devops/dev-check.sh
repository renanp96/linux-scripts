#!/usr/bin/env bash
set -o pipefail

# ================================
# Helpers de output
# ================================
ok()   { echo -e "\033[0;32m[OK]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[0;31m[FAIL]\033[0m $1"; }
info() { echo -e "\033[0;36m[INFO]\033[0m $1"; }

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
        # fallback: tenta detectar pelo gerenciador de pacotes disponível
        if command -v dnf >/dev/null 2>&1;      then DISTRO_FAMILY="rhel"
        elif command -v apt >/dev/null 2>&1;    then DISTRO_FAMILY="debian"
        elif command -v pacman >/dev/null 2>&1; then DISTRO_FAMILY="arch"
        elif command -v zypper >/dev/null 2>&1; then DISTRO_FAMILY="suse"
        elif command -v apk >/dev/null 2>&1;    then DISTRO_FAMILY="alpine"
        fi
        ;;
esac

# Mapa: nome genérico do pacote -> comando de instalação por família.
# Adicione entradas aqui quando o nome do pacote divergir entre distros.
pkg_install_hint() {
    local pkg="$1"
    case "$DISTRO_FAMILY" in
        rhel)   echo "sudo dnf install $pkg" ;;
        debian) echo "sudo apt install $pkg" ;;
        arch)   echo "sudo pacman -S $pkg" ;;
        suse)   echo "sudo zypper install $pkg" ;;
        alpine) echo "sudo apk add $pkg" ;;
        *)      echo "instale '$pkg' com o gerenciador de pacotes da sua distro" ;;
    esac
}

# Detecta se o init é systemd (alguns comandos abaixo dependem disso)
HAS_SYSTEMD=false
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi

echo "===================================="
echo " VERIFICAÇÃO AMBIENTE DEV ($DISTRO_NAME)"
echo "===================================="
info "Família de distro detectada: $DISTRO_FAMILY"
$HAS_SYSTEMD || warn "systemd não detectado — checks de serviço (Docker/Jenkins/Podman socket) serão pulados"

# ================================
# 1. Java (SDKMAN)
# ================================
echo -e "\n1. Java (SDKMAN)"
SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"
if [ -f "$SDKMAN_INIT" ]; then
    # shellcheck disable=SC1090
    source "$SDKMAN_INIT"
    if command -v java >/dev/null 2>&1; then
        java -version 2>&1 | head -n 1
        ok "Java detectado"
        if command -v sdk >/dev/null 2>&1; then
            sdk current java 2>/dev/null || warn "SDKMAN não retornou versão"
        fi
    else
        warn "SDKMAN instalado, mas Java não configurado"
    fi
else
    warn "SDKMAN não instalado"
fi

# ================================
# 2. Python
# ================================
echo -e "\n2. Python"
if command -v python3 >/dev/null 2>&1; then
    python3 --version
    ok "Python OK"
else
    warn "Python não instalado ($(pkg_install_hint python3))"
fi

# ================================
# 3. NVM
# ================================
echo -e "\n3. NVM"
NVM_INIT="$HOME/.nvm/nvm.sh"
if [ -f "$NVM_INIT" ]; then
    # shellcheck disable=SC1090
    source "$NVM_INIT" --no-use 2>/dev/null
    NVM_VERSION=$(nvm --version 2>/dev/null)
    ok "NVM instalado — versão $NVM_VERSION"
    NVM_CURRENT=$(nvm current 2>/dev/null)
    if [ "$NVM_CURRENT" != "none" ] && [ -n "$NVM_CURRENT" ]; then
        ok "Versão ativa no NVM: $NVM_CURRENT"
    else
        warn "NVM instalado mas nenhuma versão de Node ativa (rode: nvm use <versão>)"
    fi
    echo "  Versões instaladas:"
    nvm list 2>/dev/null | sed 's/^/    /'
else
    warn "NVM não instalado"
fi

# ================================
# 4. Node.js
# ================================
echo -e "\n4. Node.js"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    NODE_PATH=$(command -v node)
    ok "Node $NODE_VERSION — $NODE_PATH"
else
    warn "Node não instalado (ou NVM não inicializado no shell atual)"
fi

# ================================
# 5. npm
# ================================
echo -e "\n5. npm"
if command -v npm >/dev/null 2>&1; then
    NPM_VERSION=$(npm --version)
    ok "npm $NPM_VERSION"
    NPM_LATEST=$(npm show npm version 2>/dev/null)
    if [ -n "$NPM_LATEST" ] && [ "$NPM_VERSION" != "$NPM_LATEST" ]; then
        warn "Atualização disponível: npm $NPM_LATEST (rode: npm install -g npm)"
    fi
else
    warn "npm não encontrado"
fi

# ================================
# 6. Git
# ================================
echo -e "\n6. Git"
if command -v git >/dev/null 2>&1; then
    git --version
    GIT_USER=$(git config --global user.name 2>/dev/null)
    GIT_EMAIL=$(git config --global user.email 2>/dev/null)
    [ -n "$GIT_USER" ]  && ok "Git user: $GIT_USER" || warn "git user.name não configurado"
    [ -n "$GIT_EMAIL" ] && ok "Git email: $GIT_EMAIL" || warn "git user.email não configurado"
else
    warn "Git não instalado ($(pkg_install_hint git))"
fi

# ================================
# 7. Docker
# ================================
echo -e "\n7. Docker"
if command -v docker >/dev/null 2>&1; then
    docker --version
    ok "Docker instalado"
    if $HAS_SYSTEMD; then
        if systemctl is-active --quiet docker; then
            ok "Docker está rodando"
        else
            warn "Docker instalado mas parado (rode: sudo systemctl start docker)"
        fi
    else
        info "Sem systemd — não é possível checar status do serviço Docker automaticamente"
    fi
    if groups | grep -q docker; then
        ok "Usuário no grupo docker"
    else
        warn "Usuário NÃO está no grupo docker (sudo será necessário, ou rode: sudo usermod -aG docker \$USER)"
    fi
else
    fail "Docker não instalado ($(pkg_install_hint docker-ce 2>/dev/null || echo docker))"
fi

# ================================
# 8. Podman
# ================================
echo -e "\n8. Podman"
if command -v podman >/dev/null 2>&1; then
    PODMAN_VERSION=$(podman --version)
    ok "$PODMAN_VERSION"
    if $HAS_SYSTEMD; then
        if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
            ok "Podman socket (rootless) ativo"
        else
            warn "Podman socket inativo (rode: systemctl --user enable --now podman.socket)"
        fi
    else
        info "Sem systemd — não é possível checar o socket do Podman automaticamente"
    fi
    RUNNING=$(podman ps --format '{{.Names}}' 2>/dev/null | wc -l)
    if [ "$RUNNING" -gt 0 ]; then
        ok "$RUNNING container(s) rodando:"
        podman ps --format "  - {{.Names}} ({{.Image}})" 2>/dev/null
    else
        echo "  Nenhum container Podman em execução"
    fi
else
    warn "Podman não instalado ($(pkg_install_hint podman))"
fi

# ================================
# 9. Jenkins
# ================================
echo -e "\n9. Jenkins"
if $HAS_SYSTEMD; then
    if systemctl list-unit-files 2>/dev/null | grep -q jenkins.service; then
        if systemctl is-active --quiet jenkins; then
            ok "Jenkins rodando"
        else
            warn "Jenkins instalado mas parado"
        fi
    else
        warn "Jenkins não instalado"
    fi
else
    info "Sem systemd — checagem de serviço Jenkins pulada (verifique manualmente)"
fi

# ================================
# 10. RabbitMQ (Docker)
# ================================
echo -e "\n10. RabbitMQ (Docker)"
if command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi rabbit; then
        ok "RabbitMQ rodando"
        docker ps --filter "name=rabbit" --format "  - {{.Names}} ({{.Ports}})"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qi rabbit; then
        warn "RabbitMQ existe mas está parado"
    else
        warn "RabbitMQ não encontrado"
    fi
else
    warn "Docker necessário para verificar RabbitMQ"
fi

# ================================
# 11. Portas importantes
# ================================
echo -e "\n11. Portas importantes"
declare -A PORT_NAMES=(
    [8080]="HTTP Alt / Quarkus"
    [3000]="Node / React Dev"
    [4200]="Angular Dev"
    [5432]="PostgreSQL"
    [3306]="MariaDB/MySQL"
    [6379]="Redis"
    [5672]="RabbitMQ AMQP"
    [15672]="RabbitMQ Management"
    [27017]="MongoDB"
)

# ss (iproute2) é o padrão hoje em quase todas as distros, mas nem sempre
# está presente em imagens mínimas (ex: containers Alpine). Faz fallback
# para netstat, e senão avisa que não dá para checar portas.
PORT_CHECK_CMD=""
if command -v ss >/dev/null 2>&1; then
    PORT_CHECK_CMD="ss -tulpn"
elif command -v netstat >/dev/null 2>&1; then
    PORT_CHECK_CMD="netstat -tulpn"
fi

if [ -n "$PORT_CHECK_CMD" ]; then
    PORT_OUTPUT=$($PORT_CHECK_CMD 2>/dev/null)
    for port in "${!PORT_NAMES[@]}"; do
        if echo "$PORT_OUTPUT" | grep -q ":$port "; then
            ok "Porta $port em uso — ${PORT_NAMES[$port]}"
        else
            echo "  Porta $port livre  — ${PORT_NAMES[$port]}"
        fi
    done
else
    warn "Nem 'ss' nem 'netstat' encontrados — não é possível checar portas ($(pkg_install_hint iproute2))"
fi

# ================================
# 12. Recursos do sistema
# ================================
echo -e "\n12. Recursos do sistema"
echo "RAM:"
free -h 2>/dev/null | awk 'NR<=2' || info "'free' indisponível ($(pkg_install_hint procps))"
echo -e "\nCPU cores: $(nproc 2>/dev/null || echo "desconhecido")"
if command -v uptime >/dev/null 2>&1; then
    echo "Carga atual: $(uptime | awk -F'load average:' '{print $2}')"
fi
echo -e "\nDisco (/):"
df -h / 2>/dev/null | awk 'NR==2 {printf "  Usado: %s / %s (%s)\n", $3, $2, $5}'

# ================================
# Resumo rápido
# ================================
echo -e "\n===================================="
echo " CHECK FINALIZADO — $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================="