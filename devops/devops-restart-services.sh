#!/usr/bin/env bash

set -uo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Script de Reset de Serviços"
echo "=========================================="
echo ""

# ================================
# Detecção de init (systemd vs. OpenRC)
# ================================
HAS_SYSTEMD=false
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=true
fi
HAS_OPENRC=false
command -v rc-service >/dev/null 2>&1 && HAS_OPENRC=true

if ! $HAS_SYSTEMD && ! $HAS_OPENRC; then
    echo -e "${RED}Nenhum supervisor de serviços reconhecido (systemd/OpenRC). Abortando.${NC}"
    exit 1
fi

# ================================
# Nomes de unidade/serviço candidatos por serviço lógico
# ================================
service_candidates() {
    case "$1" in
        docker)     echo "docker" ;;
        mariadb)    echo "mariadb mysql mysqld" ;;
        postgresql) echo "postgresql" ;;   # unidades versionadas tratadas à parte (systemd)
        jenkins)    echo "jenkins" ;;
        mongodb)    echo "mongod mongodb" ;;
        rabbitmq)   echo "rabbitmq-server rabbitmq" ;;
    esac
}

# Resolve o nome real do serviço presente no sistema, ou retorna vazio.
# 'systemctl cat' é usado em vez de grep na tabela do list-unit-files —
# mais robusto e independente de formatação de saída.
resolve_service() {
    local key="$1" candidate

    if $HAS_SYSTEMD; then
        for candidate in $(service_candidates "$key"); do
            if systemctl cat "${candidate}.service" >/dev/null 2>&1; then
                echo "$candidate"
                return 0
            fi
        done
        if [ "$key" = "postgresql" ]; then
            local versioned
            versioned=$(systemctl list-unit-files 2>/dev/null | grep -oE "postgresql@[^ ]+\.service" | head -1 | sed 's/\.service$//')
            [ -n "$versioned" ] && { echo "$versioned"; return 0; }
        fi
    elif $HAS_OPENRC; then
        for candidate in $(service_candidates "$key"); do
            [ -x "/etc/init.d/$candidate" ] && { echo "$candidate"; return 0; }
        done
    fi
    return 1
}

is_service_active() {
    local name="$1"
    if $HAS_SYSTEMD; then
        systemctl is-active --quiet "$name" 2>/dev/null
    else
        rc-service "$name" status 2>/dev/null | grep -qi "started"
    fi
}

stop_service_by_name() {
    local name="$1"
    if $HAS_SYSTEMD; then
        sudo systemctl stop "$name"
    else
        sudo rc-service "$name" stop
    fi
}

start_service_by_name() {
    local name="$1"
    if $HAS_SYSTEMD; then
        sudo systemctl start "$name"
    else
        sudo rc-service "$name" start
    fi
}

# ================================
# Orquestração de parada / início por serviço lógico
# ================================
stop_service() {
    local key="$1" display="$2"
    local name

    name=$(resolve_service "$key")
    if [ -z "$name" ]; then
        echo -e "${YELLOW}$display não encontrado no sistema${NC}"
        echo ""
        return
    fi

    echo -n "Verificando $display ($name)... "
    if is_service_active "$name"; then
        echo -e "${YELLOW}rodando${NC}"
        echo -n "Encerrando $display... "
        if stop_service_by_name "$name"; then
            echo -e "${GREEN}✓ Encerrado com sucesso${NC}"
        else
            echo -e "${RED}✗ Erro ao encerrar${NC}"
        fi
    else
        echo -e "${GREEN}já está parado${NC}"
    fi
    echo ""
}

start_service() {
    local key="$1" display="$2"
    local name

    name=$(resolve_service "$key")
    if [ -z "$name" ]; then
        echo -e "${YELLOW}$display não encontrado no sistema${NC}"
        echo ""
        return
    fi

    echo -n "Verificando $display ($name)... "
    if is_service_active "$name"; then
        echo -e "${GREEN}já está rodando${NC}"
    else
        echo -e "${YELLOW}parado${NC}"
        echo -n "Iniciando $display... "
        if start_service_by_name "$name"; then
            sleep 2
            if is_service_active "$name"; then
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

# ==========================================
# FASE 1 — Encerrar tudo
# Ordem: apps/consumidores primeiro, Docker por último
# (mesma lógica do stop-services.sh)
# ==========================================
echo "############################################"
echo "  FASE 1/2 — Encerrando serviços"
echo "############################################"
echo ""

echo "--- Jenkins ---"
stop_service "jenkins" "Jenkins"

echo "--- PostgreSQL ---"
stop_service "postgresql" "PostgreSQL"

echo "--- MariaDB ---"
stop_service "mariadb" "MariaDB"

echo "--- MongoDB ---"
stop_service "mongodb" "MongoDB"

echo "--- RabbitMQ ---"
stop_service "rabbitmq" "RabbitMQ"

echo "--- Docker ---"
stop_service "docker" "Docker"
if $HAS_SYSTEMD && systemctl cat docker.socket >/dev/null 2>&1; then
    echo -n "Verificando Docker Socket... "
    if systemctl is-active --quiet docker.socket 2>/dev/null; then
        echo -e "${YELLOW}rodando${NC}"
        echo -n "Encerrando Docker Socket... "
        if sudo systemctl stop docker.socket; then
            echo -e "${GREEN}✓ Encerrado com sucesso${NC}"
        else
            echo -e "${RED}✗ Erro ao encerrar${NC}"
        fi
    else
        echo -e "${GREEN}já está parado${NC}"
    fi
    echo ""
fi

echo "--- Minikube (Kubernetes) ---"
if command -v minikube &>/dev/null; then
    echo -n "Verificando Minikube... "
    if minikube status 2>/dev/null | grep -q "Running"; then
        echo -e "${YELLOW}rodando${NC}"
        echo -n "Parando Minikube... "
        if minikube stop; then
            echo -e "${GREEN}✓ Encerrado com sucesso${NC}"
        else
            echo -e "${RED}✗ Erro ao encerrar Minikube${NC}"
        fi
    else
        echo -e "${GREEN}já está parado${NC}"
    fi
else
    echo -e "${YELLOW}Minikube não encontrado no sistema${NC}"
fi
echo ""

# ==========================================
# FASE 2 — Iniciar tudo de novo
# Ordem: Docker primeiro (outros serviços/containers podem depender dele),
# depois bancos de dados, depois apps, Minikube por último
# (mesma lógica do start-services.sh)
# ==========================================
echo "############################################"
echo "  FASE 2/2 — Iniciando serviços"
echo "############################################"
echo ""

echo "--- Docker ---"
start_service "docker" "Docker"

echo "--- MariaDB ---"
start_service "mariadb" "MariaDB"

echo "--- PostgreSQL ---"
start_service "postgresql" "PostgreSQL"

echo "--- Jenkins ---"
start_service "jenkins" "Jenkins"

echo "--- MongoDB ---"
start_service "mongodb" "MongoDB"

echo "--- RabbitMQ ---"
start_service "rabbitmq" "RabbitMQ"

echo "--- Minikube (Kubernetes) ---"
if command -v minikube &>/dev/null; then
    if ! minikube status &>/dev/null; then
        echo -e "${YELLOW}Minikube não está rodando${NC}"
        echo -n "Iniciando Minikube... "
        if minikube start --driver=podman; then
            echo -e "${GREEN}✓ Iniciado com sucesso${NC}"
        else
            echo -e "${RED}✗ Erro ao iniciar Minikube${NC}"
        fi
    else
        echo -e "${GREEN}Minikube já está rodando${NC}"
    fi
else
    echo -e "${YELLOW}Minikube não encontrado no sistema${NC}"
fi

echo ""
echo "=========================================="
echo "  Resumo Final dos Serviços"
echo "=========================================="
echo ""

service_keys=("docker" "mariadb" "postgresql" "jenkins" "mongodb" "rabbitmq")
display_names=("Docker" "MariaDB" "PostgreSQL" "Jenkins" "MongoDB" "RabbitMQ")

for i in "${!service_keys[@]}"; do
    key="${service_keys[$i]}"
    display="${display_names[$i]}"
    name=$(resolve_service "$key")
    echo -n "$display: "
    if [ -z "$name" ]; then
        echo -e "${YELLOW}não encontrado${NC}"
    elif is_service_active "$name"; then
        echo -e "${GREEN}✓ Rodando${NC}"
    else
        echo -e "${RED}✗ Parado${NC}"
    fi
done

if command -v minikube &>/dev/null; then
    echo -n "Minikube: "
    if minikube status 2>/dev/null | grep -q "Running"; then
        echo -e "${GREEN}✓ Rodando${NC}"
    else
        echo -e "${RED}✗ Parado${NC}"
    fi
fi

echo ""
echo "Reset concluído!"