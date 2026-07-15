#!/usr/bin/env bash

# ==========================================
# Script para iniciar serviços: Docker, MariaDB, PostgreSQL,
# Jenkins, MongoDB, RabbitMQ e Minikube
# Autor: Renan P Andrade
# Multi-distro (systemd e OpenRC)
# ==========================================

set -uo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  Script de Inicialização de Serviços"
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
# (a variação vem mais da origem do pacote — repo oficial vs. da distro —
# do que estritamente da família da distro, por isso tentamos uma lista)
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

# Resolve o nome real do serviço presente no sistema, ou retorna vazio
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

# ================================
# Checagem / início de um serviço já resolvido
# ================================
is_service_active() {
    local name="$1"
    if $HAS_SYSTEMD; then
        systemctl is-active --quiet "$name" 2>/dev/null
    else
        rc-service "$name" status 2>/dev/null | grep -qi "started"
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

# Orquestra: resolve nome real -> verifica -> inicia se necessário
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

# ================================
# Iniciar cada serviço
# ================================
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

# ================================
# Minikube (Kubernetes local) — independente de distro/init
# ================================
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

echo "=========================================="
echo "  Resumo dos Serviços"
echo "=========================================="
echo ""

# ================================
# Resumo final — resolve de novo para refletir os nomes reais usados
# ================================
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
echo "Operação concluída!"