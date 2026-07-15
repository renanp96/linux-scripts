#!/usr/bin/env bash

set -uo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  Script de Encerramento de Serviços"
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
# Usa 'systemctl cat' em vez de fazer grep na tabela do list-unit-files —
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

# Orquestra: resolve nome real -> verifica -> encerra se necessário
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

# ================================
# Encerrar serviços — ordem inversa da inicialização:
# apps/consumidores primeiro, Docker por último (várias ferramentas
# dependem dele, então convém ser o último a cair)
# ================================
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

# ================================
# Minikube (Kubernetes local) — independente de distro/init
# ================================
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

echo "=========================================="
echo "  Resumo dos Serviços"
echo "=========================================="
echo ""

# ================================
# Resumo final — resolve de novo pra refletir os nomes reais usados
# ================================
service_keys=("jenkins" "postgresql" "mariadb" "mongodb" "rabbitmq" "docker")
display_names=("Jenkins" "PostgreSQL" "MariaDB" "MongoDB" "RabbitMQ" "Docker")

for i in "${!service_keys[@]}"; do
    key="${service_keys[$i]}"
    display="${display_names[$i]}"
    name=$(resolve_service "$key")
    echo -n "$display: "
    if [ -z "$name" ]; then
        echo -e "${YELLOW}não encontrado${NC}"
    elif is_service_active "$name"; then
        echo -e "${RED}Rodando${NC}"
    else
        echo -e "${GREEN}Parado${NC}"
    fi
done

if $HAS_SYSTEMD && systemctl cat docker.socket >/dev/null 2>&1; then
    echo -n "Docker Socket: "
    if systemctl is-active --quiet docker.socket 2>/dev/null; then
        echo -e "${RED}Rodando${NC}"
    else
        echo -e "${GREEN}Parado${NC}"
    fi
fi

if command -v minikube &>/dev/null; then
    echo -n "Minikube: "
    if minikube status 2>/dev/null | grep -q "Running"; then
        echo -e "${RED}Rodando${NC}"
    else
        echo -e "${GREEN}Parado${NC}"
    fi
fi

echo ""
echo "Operação concluída!"