#!/bin/bash

# Script para encerrar serviços: Docker, MariaDB, PostgreSQL e Jenkins
# Autor: Renan P Andrade
# Data: $(date +%Y-%m-%d)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Script de Encerramento de Serviços"
echo "=========================================="
echo ""

# Função para verificar se um serviço está rodando
check_service() {
    systemctl is-active --quiet "$1"
    return $?
}

# Função para parar um serviço
stop_service() {
    local service_name=$1
    local display_name=$2
    
    echo -n "Verificando $display_name... "
    
    if check_service "$service_name"; then
        echo -e "${YELLOW}rodando${NC}"
        echo -n "Encerrando $display_name... "
        
        if sudo systemctl stop "$service_name"; then
            echo -e "${GREEN}✓ Encerrado com sucesso${NC}"
        else
            echo -e "${RED}✗ Erro ao encerrar${NC}"
        fi
    else
        echo -e "${GREEN}já está parado${NC}"
    fi
    echo ""
}

# Encerrar Jenkins
echo "--- Jenkins ---"
if systemctl list-unit-files | grep -q "jenkins.service"; then
    stop_service "jenkins" "Jenkins"
else
    echo -e "${YELLOW}Jenkins não encontrado no sistema${NC}"
    echo ""
fi

# Encerrar PostgreSQL
echo "--- PostgreSQL ---"
stop_service "postgresql" "PostgreSQL"

# Encerrar MariaDB
echo "--- MariaDB ---"
if systemctl list-unit-files | grep -q "mariadb.service"; then
    stop_service "mariadb" "MariaDB"
elif systemctl list-unit-files | grep -q "mysql.service"; then
    stop_service "mysql" "MariaDB (mysql)"
else
    echo -e "${YELLOW}MariaDB não encontrado no sistema${NC}"
    echo ""
fi

# Encerrar Docker (por último)
echo "--- Docker ---"
stop_service "docker" "Docker"

echo "=========================================="
echo "  Resumo dos Serviços"
echo "=========================================="
echo ""

# Mostrar status final
services=("jenkins" "postgresql" "mariadb" "docker")
display_names=("Jenkins" "PostgreSQL" "MariaDB" "Docker")

for i in "${!services[@]}"; do
    service="${services[$i]}"
    display="${display_names[$i]}"
    
    echo -n "$display: "
    if check_service "$service" 2>/dev/null; then
        echo -e "${RED}Rodando${NC}"
    else
        echo -e "${GREEN}Parado${NC}"
    fi
done

echo ""
echo "Operação concluída!"
