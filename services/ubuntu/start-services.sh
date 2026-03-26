#!/bin/bash

# Script para iniciar serviços: Docker, MariaDB, PostgreSQL e Jenkins
# Autor: Renan P Andrade
# Data: $(date +%Y-%m-%d)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Script de Inicialização de Serviços"
echo "=========================================="
echo ""

# Função para verificar se um serviço está rodando
check_service() {
    systemctl is-active --quiet "$1"
    return $?
}

# Função para iniciar um serviço
start_service() {
    local service_name=$1
    local display_name=$2
    
    echo -n "Verificando $display_name... "
    
    if check_service "$service_name"; then
        echo -e "${GREEN}já está rodando${NC}"
    else
        echo -e "${YELLOW}parado${NC}"
        echo -n "Iniciando $display_name... "
        
        if sudo systemctl start "$service_name"; then
            sleep 2
            if check_service "$service_name"; then
                echo -e "${GREEN}✓ Iniciado com sucesso${NC}"
            else
                echo -e "${RED}✗ Iniciado mas não está respondendo${NC}"
            fi
        else
            echo -e "${RED}✗ Erro ao iniciar${NC}"
        fi
    fi
    echo ""
}

# Iniciar Docker
echo "--- Docker ---"
start_service "docker" "Docker"

# Iniciar MariaDB
echo "--- MariaDB ---"
if systemctl list-unit-files | grep -q "mariadb.service"; then
    start_service "mariadb" "MariaDB"
elif systemctl list-unit-files | grep -q "mysql.service"; then
    start_service "mysql" "MariaDB (mysql)"
else
    echo -e "${YELLOW}MariaDB não encontrado no sistema${NC}"
    echo ""
fi

# Iniciar PostgreSQL
echo "--- PostgreSQL ---"
start_service "postgresql" "PostgreSQL"

# Iniciar Jenkins
echo "--- Jenkins ---"
if systemctl list-unit-files | grep -q "jenkins.service"; then
    start_service "jenkins" "Jenkins"
else
    echo -e "${YELLOW}Jenkins não encontrado no sistema${NC}"
    echo ""
fi

echo "=========================================="
echo "  Resumo dos Serviços"
echo "=========================================="
echo ""

# Mostrar status final
services=("docker" "mariadb" "postgresql" "jenkins")
display_names=("Docker" "MariaDB" "PostgreSQL" "Jenkins")

for i in "${!services[@]}"; do
    service="${services[$i]}"
    display="${display_names[$i]}"
    
    echo -n "$display: "
    if check_service "$service" 2>/dev/null; then
        echo -e "${GREEN}✓ Rodando${NC}"
    else
        echo -e "${RED}✗ Parado${NC}"
    fi
done

echo ""
echo "Operação concluída!"
