#!/usr/bin/env bash
echo "===================================="
echo " VERIFICAÇÃO AMBIENTE DEV (FEDORA)"
echo "===================================="

# ================================
# Helpers
# ================================
ok()   { echo -e "\033[0;32m[OK]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[0;31m[FAIL]\033[0m $1"; }

# ================================
# 1. Java (SDKMAN)
# ================================
echo -e "\n1. Java (SDKMAN)"
SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"
if [ -f "$SDKMAN_INIT" ]; then
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
    warn "Python não instalado"
fi

# ================================
# 3. NVM
# ================================
echo -e "\n3. NVM"
NVM_INIT="$HOME/.nvm/nvm.sh"
if [ -f "$NVM_INIT" ]; then
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
    # Verificar se há atualização disponível
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
    warn "Git não instalado"
fi

# ================================
# 7. Docker
# ================================
echo -e "\n7. Docker"
if command -v docker >/dev/null 2>&1; then
    docker --version
    ok "Docker instalado"
    if systemctl is-active --quiet docker; then
        ok "Docker está rodando"
    else
        warn "Docker instalado mas parado"
    fi
    if groups | grep -q docker; then
        ok "Usuário no grupo docker"
    else
        warn "Usuário NÃO está no grupo docker (sudo será necessário)"
    fi
else
    fail "Docker não instalado"
fi

# ================================
# 8. Podman
# ================================
echo -e "\n8. Podman"
if command -v podman >/dev/null 2>&1; then
    PODMAN_VERSION=$(podman --version)
    ok "$PODMAN_VERSION"
    # Verificar socket do Podman (rootless)
    if systemctl --user is-active --quiet podman.socket 2>/dev/null; then
        ok "Podman socket (rootless) ativo"
    else
        warn "Podman socket inativo (rode: systemctl --user enable --now podman.socket)"
    fi
    # Containers em execução
    RUNNING=$(podman ps --format '{{.Names}}' 2>/dev/null | wc -l)
    if [ "$RUNNING" -gt 0 ]; then
        ok "$RUNNING container(s) rodando:"
        podman ps --format "  - {{.Names}} ({{.Image}})" 2>/dev/null
    else
        echo "  Nenhum container Podman em execução"
    fi
else
    warn "Podman não instalado (dnf install podman)"
fi

# ================================
# 9. Jenkins
# ================================
echo -e "\n9. Jenkins"
if systemctl list-unit-files | grep -q jenkins.service; then
    if systemctl is-active --quiet jenkins; then
        ok "Jenkins rodando"
    else
        warn "Jenkins instalado mas parado"
    fi
else
    warn "Jenkins não instalado"
fi

# ================================
# 10. RabbitMQ (Docker)
# ================================
echo -e "\n10. RabbitMQ (Docker)"
if command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Names}}' | grep -qi rabbit; then
        ok "RabbitMQ rodando"
        docker ps --filter "name=rabbit" --format "  - {{.Names}} ({{.Ports}})"
    elif docker ps -a --format '{{.Names}}' | grep -qi rabbit; then
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
for port in "${!PORT_NAMES[@]}"; do
    if ss -tulpn | grep -q ":$port "; then
        ok "Porta $port em uso — ${PORT_NAMES[$port]}"
    else
        echo "  Porta $port livre  — ${PORT_NAMES[$port]}"
    fi
done

# ================================
# 12. Recursos do sistema
# ================================
echo -e "\n12. Recursos do sistema"
echo "RAM:"
free -h | awk 'NR<=2'
echo -e "\nCPU cores: $(nproc)"
echo "Carga atual: $(uptime | awk -F'load average:' '{print $2}')"
echo -e "\nDisco (/):"
df -h / | awk 'NR==2 {printf "  Usado: %s / %s (%s)\n", $3, $2, $5}'

# ================================
# Resumo rápido
# ================================
echo -e "\n===================================="
echo " CHECK FINALIZADO — $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================="