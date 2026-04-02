#!/usr/bin/env bash

echo "===================================="
echo " VERIFICAÇÃO AMBIENTE DEV (FEDORA)"
echo "===================================="

# ================================
# Helpers
# ================================
ok() { echo -e "\033[0;32m[OK]\033[0m $1"; }
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
# 3. Node.js
# ================================
echo -e "\n3. Node.js"

if command -v node >/dev/null 2>&1; then
  node --version
  ok "Node OK"
else
  warn "Node não instalado"
fi

# ================================
# 4. Git
# ================================
echo -e "\n4. Git"

if command -v git >/dev/null 2>&1; then
  git --version
  ok "Git OK"
else
  warn "Git não instalado"
fi

# ================================
# 5. Docker
# ================================
echo -e "\n5. Docker"

if command -v docker >/dev/null 2>&1; then
  docker --version
  ok "Docker instalado"

  if systemctl is-active --quiet docker; then
    ok "Docker está rodando"
  else
    warn "Docker instalado mas parado"
  fi

  # Permissão do usuário
  if groups | grep -q docker; then
    ok "Usuário no grupo docker"
  else
    warn "Usuário NÃO está no grupo docker (sudo será necessário)"
  fi

else
  fail "Docker não instalado"
fi

# ================================
# 6. Jenkins
# ================================
echo -e "\n6. Jenkins"

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
# 7. RabbitMQ (Docker)
# ================================
echo -e "\n7. RabbitMQ (Docker)"

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
# 8. Portas importantes
# ================================
echo -e "\n8. Portas importantes"

PORTS=(8080 3000 5432 3306 6379 5672)

for port in "${PORTS[@]}"; do
  if ss -tulpn | grep -q ":$port "; then
    ok "Porta $port em uso"
  else
    echo "Porta $port livre"
  fi
done

# ================================
# 9. Recursos do sistema
# ================================
echo -e "\n9. Recursos do sistema"

echo "RAM:"
free -h

echo -e "\nCPU:"
nproc

# ================================
# 10. Resumo rápido
# ================================
echo -e "\n===================================="
echo " CHECK FINALIZADO"
echo "===================================="