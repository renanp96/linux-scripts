# 🌐 Net Tools — Scripts de Conexão com a Internet

> Conjunto de scripts Bash para verificação pontual, monitoramento contínuo e otimização de rede no Linux.
>
> **Autor:** Renan P Andrade
> **Data:** 2026-05-17
> **Ambiente:** Fedora KDE Plasma (compatível com qualquer distro com systemd)

---

## 📁 Estrutura

```
.
├── check-internet.sh       # Verificação pontual de conexão
├── monitor-internet.sh     # Monitoramento contínuo em background
├── optimize-internet.sh    # Limpeza de cache e otimização TCP/IP
└── README.md
```

---

## ⚙️ Dependências

| Ferramenta     | Uso                                      | Obrigatório |
|----------------|------------------------------------------|-------------|
| `ping`         | Teste de conectividade e latência        | ✅ Sim       |
| `curl`         | Estimativa de velocidade de download     | ⚠️ Recomendado |
| `ip`           | Interfaces, rotas e cache ARP            | ✅ Sim       |
| `nslookup`     | Resolução de DNS                         | ✅ Sim       |
| `bc`           | Cálculos de velocidade                   | ⚠️ Recomendado |
| `systemctl`    | Gerenciamento de serviços                | ✅ Sim       |
| `resolvectl`   | Flush de cache DNS (systemd-resolved)    | ✅ Sim       |
| `sysctl`       | Otimização de parâmetros do kernel       | ✅ Sim       |

---

## 🚀 Instalação

```bash
# Clonar / copiar os arquivos para o diretório desejado, depois:
chmod +x check-internet.sh monitor-internet.sh optimize-internet.sh
```

---

## 📄 Scripts

### 1. `check-internet.sh` — Verificação Pontual

Executa uma série de testes de conectividade e exibe um resumo no terminal.

**O que verifica:**
- Interfaces de rede ativas (UP/DOWN)
- Gateway local (detecção automática + ping)
- Conectividade externa via ping para `8.8.8.8`, `1.1.1.1` e `9.9.9.9`
- Resolução de DNS para `google.com` e `cloudflare.com`
- Estimativa de velocidade de download (arquivo de teste de 1 MB)

**Uso:**
```bash
./check-internet.sh
```

**Exemplo de saída:**
```
==========================================
   Verificação de Conexão com a Internet
==========================================

--- Interfaces de Rede Ativas ---
  ▲ eth0 — 192.168.1.10/24
  ▲ lo   — 127.0.0.1/8

--- Gateway Local ---
Gateway detectado (192.168.1.1)... ✓ Acessível

--- Conectividade Externa (Ping) ---
Pingando 8.8.8.8... ✓ OK (avg 12.3 ms)
Pingando 1.1.1.1... ✓ OK (avg 10.8 ms)
Pingando 9.9.9.9... ✓ OK (avg 14.1 ms)

--- Resolução de DNS ---
Resolvendo google.com... ✓ OK (142.250.79.46)
Resolvendo cloudflare.com... ✓ OK (104.16.133.229)

--- Estimativa de Velocidade ---
Baixando arquivo de teste (1MB)... ✓ Concluído
  Tempo: 423 ms | Velocidade estimada: 18.92 Mbps

==========================================
   Resumo Final
==========================================

Conectividade externa: ✓ OK
Resolução de DNS:      ✓ OK

Verificação concluída em: 2026-05-17 10:30:00
```

> **Não requer `sudo`.**

---

### 2. `monitor-internet.sh` — Monitoramento Contínuo

Roda em background como um daemon leve, registrando eventos de rede em um arquivo de log com timestamps precisos.

**O que monitora:**
- Quedas de conexão (sem resposta de `8.8.8.8`)
- Duração de cada queda e horário de recuperação
- Quedas bruscas de velocidade (abaixo do threshold configurado)
- Velocidade de download a cada 60 segundos

**Configurações (editáveis no topo do script):**

| Variável               | Padrão                                      | Descrição                                 |
|------------------------|---------------------------------------------|-------------------------------------------|
| `CHECK_INTERVAL`       | `10`                                        | Segundos entre verificações de ping       |
| `SPEED_CHECK_INTERVAL` | `60`                                        | Segundos entre testes de velocidade       |
| `SPEED_DROP_THRESHOLD` | `5`                                         | Mbps mínimo antes de registrar queda      |
| `PING_HOST`            | `8.8.8.8`                                   | Host usado para teste de conectividade    |
| `LOG_FILE`             | `~/.local/share/net-monitor/internet-monitor.log` | Caminho do arquivo de log          |

**Uso:**
```bash
./monitor-internet.sh start    # Inicia monitoramento em background
./monitor-internet.sh stop     # Para o monitoramento
./monitor-internet.sh status   # Exibe status e últimas 20 linhas do log
./monitor-internet.sh log      # Exibe o log completo
```

**Exemplo de log (`~/.local/share/net-monitor/internet-monitor.log`):**
```
[2026-05-17 10:00:00] [INFO]     Monitoramento iniciado (PID 12345)
[2026-05-17 10:00:00] [INFO]     Intervalo de ping: 10s | Threshold velocidade: 5 Mbps
[2026-05-17 10:01:00] [SPEED]    Velocidade OK — 18.92 Mbps
[2026-05-17 10:15:34] [DOWN]     QUEDA DE CONEXÃO detectada — sem resposta de 8.8.8.8
[2026-05-17 10:15:44] [DOWN]     Conexão ainda indisponível (queda desde: 2026-05-17 10:15:34)
[2026-05-17 10:16:02] [RECOVERY] Conexão restaurada após ~28s de queda (queda iniciada: 2026-05-17 10:15:34)
[2026-05-17 10:21:00] [SLOW]     QUEDA DE VELOCIDADE detectada — 1.23 Mbps (threshold: 5 Mbps)
```

**Níveis de log:**

| Nível      | Significado                                      |
|------------|--------------------------------------------------|
| `INFO`     | Eventos informativos (início, configurações)     |
| `SPEED`    | Velocidade medida dentro do esperado             |
| `SLOW`     | Velocidade abaixo do threshold                   |
| `DOWN`     | Queda de conexão detectada                       |
| `RECOVERY` | Conexão restaurada após queda                    |

> **Não requer `sudo`.** O processo sobrevive ao fechamento do terminal.

---

### 3. `optimize-internet.sh` — Limpeza e Otimização

Aplica uma série de otimizações de rede e limpa caches acumulados pelo sistema.

**O que faz:**

| Etapa | Ação |
|-------|------|
| Cache DNS | Reinicia `systemd-resolved`, invalida cache do `nscd` e executa `resolvectl flush-caches` |
| Cache ARP | Limpa a tabela de vizinhos com `ip neigh flush all` |
| Rotas | Limpa o cache de rotas do kernel via `/proc/sys/net/ipv4/route/flush` |
| Parâmetros TCP | Aplica otimizações de buffer, BBR, Fast Open e keepalive via `sysctl` |
| NetworkManager | Reinicia o serviço e verifica reconexão |
| resolv.conf | Verifica integridade do symlink |

**Parâmetros `sysctl` aplicados:**

| Parâmetro                          | Valor           | Efeito                                  |
|------------------------------------|-----------------|-----------------------------------------|
| `net.core.rmem_max`                | `16777216`      | Buffer de recepção máximo (16 MB)       |
| `net.core.wmem_max`                | `16777216`      | Buffer de envio máximo (16 MB)          |
| `net.ipv4.tcp_rmem`                | `4096 87380 16777216` | Buffer TCP de recepção adaptativo |
| `net.ipv4.tcp_wmem`                | `4096 65536 16777216` | Buffer TCP de envio adaptativo    |
| `net.ipv4.tcp_fastopen`            | `3`             | Fast Open para cliente e servidor       |
| `net.ipv4.tcp_congestion_control`  | `bbr`           | Algoritmo BBR (menor latência)          |
| `net.core.default_qdisc`           | `fq`            | Fair Queue para melhor throughput       |
| `net.ipv4.tcp_fin_timeout`         | `15`            | Libera conexões mais rapidamente        |
| `net.ipv4.tcp_keepalive_time`      | `300`           | Mantém conexões vivas por 5 min         |
| `net.ipv4.tcp_tw_reuse`            | `1`             | Reutiliza sockets TIME_WAIT             |

**Uso:**
```bash
sudo ./optimize-internet.sh
```

> ⚠️ **Requer `sudo`.** As otimizações de `sysctl` são aplicadas em tempo de execução e não persistem após reboot. Para torná-las permanentes, adicione os parâmetros em `/etc/sysctl.d/99-net-optimize.conf`.

---

## 💡 Dicas de Uso

**Tornar as otimizações de sysctl permanentes:**
```bash
sudo tee /etc/sysctl.d/99-net-optimize.conf > /dev/null <<EOF
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_tw_reuse = 1
EOF
sudo sysctl --system
```

**Iniciar o monitor automaticamente no login:**
```bash
# Adicionar ao ~/.bashrc ou ~/.zshrc:
~/.local/bin/monitor-internet.sh start 2>/dev/null
```

**Filtrar apenas quedas no log:**
```bash
grep -E "\[DOWN\]|\[RECOVERY\]|\[SLOW\]" ~/.local/share/net-monitor/internet-monitor.log
```

---

## 📋 Notas

- Os scripts são compatíveis com qualquer distribuição Linux que use `systemd` e `NetworkManager`.
- Parâmetros `sysctl` marcados como `⚠ Ignorado` indicam que o kernel não suporta aquela configuração — não é um erro crítico.
- O `monitor-internet.sh` cria automaticamente o diretório `~/.local/share/net-monitor/` se não existir.
- O teste de velocidade usa um servidor público de 1 MB (`speedtest.tele2.net`) — resultados podem variar conforme a carga do servidor.