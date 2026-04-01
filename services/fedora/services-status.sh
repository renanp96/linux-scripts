#!/bin/bash

# Script para verificar status dos serviços
# Autor: Renan P Andrade
# Data: $(date +%Y-%m-%d)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "       Status dos Serviços"
echo "=========================================="
echo ""

# Função para verificar status de um serviço systemd
check_service() {
    local service_name=$1
    local display_name=$2
    
    echo -n "$display_name: "
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}Rodando${NC}"
    else
        echo -e "${RED}Parado${NC}"
    fi
}

# Lista de serviços systemd
services=("docker" "mariadb" "mysql" "postgresql" "mongod" "jenkins" "rabbitmq-server")
display_names=("Docker" "MariaDB" "MariaDB (MySQL fallback)" "PostgreSQL" "MongoDB" "Jenkins" "RabbitMQ")

for i in "${!services[@]}"; do
    service="${services[$i]}"
    display="${display_names[$i]}"
    if systemctl list-unit-files | grep -q "$service.service"; then
        check_service "$service" "$display"
    else
        echo -e "$display: ${YELLOW}Não encontrado${NC}"
    fi
done

# Status do Minikube
echo -n "Minikube: "
if command -v minikube &>/dev/null; then
    if minikube status | grep -q "Running"; then
        echo -e "${GREEN}Rodando${NC}"
    else
        echo -e "${RED}Parado${NC}"
    fi
else
    echo -e "${YELLOW}Não encontrado${NC}"
fi

echo ""
echo "Verificação concluída!"