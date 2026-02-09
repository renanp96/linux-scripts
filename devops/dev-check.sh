#!/bin/bash

echo "Verificando ambiente dev..."

# 1. Java (SDKMAN)
echo -e "\n1. Java (SDKMAN):"

SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"

if [ -f "$SDKMAN_INIT" ]; then
  source "$SDKMAN_INIT"

  if command -v java >/dev/null 2>&1; then
    java -version
    echo "Java gerenciado pelo SDKMAN:"
    sdk current java 2>/dev/null || echo "Não foi possível identificar a versão no SDKMAN"
  else
    echo "SDKMAN instalado, mas Java não configurado"
  fi
else
  echo "SDKMAN não instalado"
fi

# 2. Python
echo -e "\n2. Python:"
python3 --version 2>/dev/null || echo "Python não instalado"

# 3. Node.js
echo -e "\n3. Node.js:"
node --version 2>/dev/null || echo "Node.js não instalado"

# 4. Git
echo -e "\n4. Git:"
git --version 2>/dev/null || echo "Git não instalado"

# 5. Docker
echo -e "\n5. Docker:"
docker --version 2>/dev/null || echo "Docker não instalado"

# 6. Jenkins
echo -e "\n6. Jenkins:"
if systemctl is-active --quiet jenkins; then
  echo "Jenkins está rodando"
elif systemctl list-unit-files | grep -q jenkins.service; then
  echo "Jenkins instalado, mas parado"
else
  echo "Jenkins não instalado"
fi

# 7. RabbitMQ (Docker)
echo -e "\n7. RabbitMQ (Docker):"
if docker ps --format '{{.Names}}' | grep -qi rabbit; then
  echo "RabbitMQ container está rodando:"
  docker ps --filter "name=rabbit" --format "  - {{.Names}} ({{.Ports}})"
elif docker ps -a --format '{{.Names}}' | grep -qi rabbit; then
  echo "RabbitMQ container existe, mas está parado"
else
  echo "RabbitMQ não encontrado em containers Docker"
fi

# 8. Portas em uso
echo -e "\n8. Portas em uso:"
ss -tulpn | grep LISTEN || echo "Nenhuma porta escutando"
