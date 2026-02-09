#!/usr/bin/env bash
set -e

echo "Atualizando sistema..."

sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

echo "Sistema atualizado com sucesso."