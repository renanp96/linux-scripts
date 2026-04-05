#!/usr/bin/env bash

# ==========================================
# STATUS DE SERVIÇOS - UBUNTU (PRO VERSION)
# Autor: Renan P Andrade
# ==========================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}        STATUS DOS SERVIÇOS (UBUNTU)     ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo

# ==========================================
# Funções
# ==========================================
check_service() {
    local service_name=$1
    local display_name=$2

    printf "%-25s" "$display_name:"

    if ! systemctl list-unit-files | grep -q "^$service_name.service"; then
        echo -e "${YELLOW}Não instalado${NC}"
        return
    fi

    STATUS=$(systemctl is-active "$service_name" 2>/dev/null)

    case "$STATUS" in
        active)
            echo -e "${GREEN}Rodando${NC}"
            ;;
        inactive)
            echo -e "${YELLOW}Parado${NC}"
            ;;
        failed)
            echo -e "${RED}Erro (failed)${NC}"
            ;;
        *)
            echo -e "${RED}Desconhecido${NC}"
            ;;
    esac
}

# ==========================================
# Serviços principais
# ==========================================
echo -e "${BLUE}>>> Serviços principais${NC}"
echo

check_service "docker" "Docker"

# Banco de dados (fallback inteligente)
if systemctl list-unit-files | grep -q "mariadb.service"; then
    check_service "mariadb" "MariaDB"
elif systemctl list-unit-files | grep -q "mysql.service"; then
    check_service "mysql" "MySQL"
else
    echo -e "Banco de Dados: ${YELLOW}Não instalado${NC}"
fi

check_service "postgresql" "PostgreSQL"
check_service "mongod" "MongoDB"
check_service "jenkins" "Jenkins"
check_service "rabbitmq-server" "RabbitMQ"

# ==========================================
# Docker containers (extra útil)
# ==========================================
echo
echo -e "${BLUE}>>> Containers Docker${NC}"
echo

if command -v docker >/dev/null 2>&1; then
    if systemctl is-active --quiet docker; then
        docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Sem containers"
    else
        echo -e "${YELLOW}Docker parado${NC}"
    fi
else
    echo -e "${YELLOW}Docker não instalado${NC}"
fi

# ==========================================
# Minikube
# ==========================================
echo
echo -e "${BLUE}>>> Kubernetes (Minikube)${NC}"
echo

if command -v minikube >/dev/null 2>&1; then
    STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null)

    if [[ "$STATUS" == "Running" ]]; then
        echo -e "${GREEN}Minikube rodando${NC}"
    else
        echo -e "${YELLOW}Minikube parado${NC}"
    fi
else
    echo -e "${YELLOW}Minikube não instalado${NC}"
fi

# ==========================================
# Portas importantes (dev backend)
# ==========================================
echo
echo -e "${BLUE}>>> Portas importantes${NC}"
echo

PORTS=(8080 5432 3306 27017 5672)

for port in "${PORTS[@]}"; do
    if ss -tulpn | grep -q ":$port "; then
        echo -e "Porta $port: ${GREEN}Em uso${NC}"
    else
        echo -e "Porta $port: ${YELLOW}Livre${NC}"
    fi
done

# ==========================================
# Final
# ==========================================
echo
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}         VERIFICAÇÃO CONCLUÍDA           ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo