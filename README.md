# linux-scripts

Coleção pessoal de scripts para manutenção, diagnóstico e automação em Linux — pensada para funcionar **na mesma versão** em qualquer uma das principais famílias de distro (RHEL/Fedora, Debian/Ubuntu, Arch, openSUSE, Alpine), em vez de manter um script separado por distribuição.

---

## Filosofia: um script, todas as distros

A abordagem antiga de manter uma pasta por distro (`fedora/`, `ubuntu/`, etc.) com uma cópia quase idêntica do mesmo script em cada uma foi abandonada. O problema: qualquer correção de bug ou melhoria precisa ser replicada manualmente em N lugares, e é fácil elas divergirem com o tempo sem ninguém perceber.

Em vez disso, cada script **detecta em tempo de execução**:

- **Família da distro** (via `/etc/os-release`, campos `ID`/`ID_LIKE`, com fallback pra detecção do gerenciador de pacotes presente)
- **Tipo de init** (`systemd` vs. `OpenRC`, relevante pra Alpine e outras distros minimalistas)
- **Se é um sistema de imagem imutável** (`rpm-ostree`: Silverblue/Kinoite/Bazzite; `transactional-update`: openSUSE MicroOS/Aeon)

...e ajusta o comportamento internamente. O resultado é **um arquivo só por funcionalidade**, que roda igual em qualquer máquina.

---

## Estrutura de pastas

```
linux-scripts/
├── devops/
│   ├── dev-check.sh              # ambiente de desenvolvimento (Java/SDKMAN, Node/NVM, Docker, Podman, Jenkins...)
│   ├── internet-check.sh         # diagnóstico pontual de conectividade (gateway, ping, DNS, velocidade)
│   ├── monitor-internet.sh       # monitor de conexão em background, com log de quedas
│   └── optimize-network.sh       # limpeza de cache de rede + tuning de sysctl (requer root)
│
├── gaming/
│   ├── gaming-check.sh           # diagnóstico do ambiente gamer (Steam, Wine, GPU, Vulkan, 32-bit...)
│   ├── gaming-install-deps.sh    # instalação das dependências gamer (requer root)
│   └── clean-gaming-cache.sh     # limpeza de shader cache, downloads incompletos, compatdata do Steam
│
├── maintence/
│   ├── system-update.sh          # atualização do sistema + Flatpak (requer root)
│   ├── system-health.sh          # diagnóstico geral (disco, memória, serviços falhos, logs de erro...)
│   ├── hardware-health-check.sh  # saúde de hardware (CPU, RAM/ECC, SMART, GPU, bateria, sensores...)
│   └── autofix-system-errors.sh  # correção automática de problemas comuns (requer root — o mais invasivo da suíte)
│
├── services/
│   ├── devops-services-status.sh # status dos serviços de dev (Docker, bancos de dados, Jenkins, RabbitMQ...)
│   ├── start-services.sh         # inicia os serviços acima (requer root)
│   ├── stop-services.sh          # encerra os serviços acima, em ordem segura (requer root)
│   └── reset-services.sh         # stop + start completo (requer root)
│
├── user/
│   ├── clean-user-cache.sh       # limpeza de cache de usuário (navegadores, desktop, Flatpak, /tmp)
│   └── dotfiles-backup.sh        # versiona dotfiles essenciais num repo git via symlinks
│
└── README.md
```

Cada pasta é uma **categoria funcional**, não uma distro. Dentro dela, cada `.sh` já sabe se adaptar sozinho.

---

## Como cada script decide o que fazer

A maioria começa com o mesmo bloco de detecção (copiado e ajustado conforme a necessidade de cada script):

```bash
DISTRO_FAMILY="unknown"   # rhel | debian | arch | suse | alpine

if [ -f /etc/os-release ]; then
    source /etc/os-release
    # classifica por ID/ID_LIKE (fedora/rhel/centos → rhel, debian/ubuntu → debian, etc.)
fi
# fallback: se não deu pra classificar, detecta pelo gerenciador de pacotes presente
# (dnf → rhel, apt → debian, pacman → arch, zypper → suse, apk → alpine)
```

```bash
HAS_SYSTEMD=false
command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && HAS_SYSTEMD=true
```

A partir daí, os scripts usam duas funções auxiliares recorrentes:

- **`pkg_name(chave)`** — traduz um nome lógico de pacote (ex: `lm-sensors`) pro nome real na distro atual (`lm_sensors` no Fedora/Arch, `lm-sensors` no Debian/Alpine, `sensors` no openSUSE)
- **`pkg_install_hint(chave)`** — monta o comando de instalação certo (`dnf install`/`apt install`/`pacman -S`/`zypper install`/`apk add`)

Nos scripts que lidam com **serviços** (`services/`), em vez de mapear rigidamente "distro X → nome de unidade Y", usamos uma lista de **nomes candidatos** por serviço lógico (ex: MariaDB pode ser `mariadb.service` ou `mysqld.service` dependendo de como foi instalado) e o script tenta cada um até achar o que existe de fato — isso cobre mais casos reais do que um mapa fixo por distro conseguiria.

---

## Convenções seguidas em todos os scripts

- **`set -uo pipefail`, não `set -e`** — em scripts com várias etapas independentes, uma falha pontual não deve abortar o resto. Cada etapa trata seu próprio erro e segue em frente.
- **Diagnóstico vs. correção são scripts separados.** Nada que só lê o sistema (`*-check.sh`, `*-status.sh`, `system-health.sh`) executa ações destrutivas. Scripts que corrigem/instalam/param algo (`autofix-*`, `*-install-*`, `start/stop/reset-services`) são os únicos que pedem root.
- **Backup antes de qualquer sobrescrita destrutiva.** Onde faz sentido (`autofix-system-errors.sh`, `dotfiles-backup.sh`), o script guarda uma cópia do estado anterior antes de mexer.
- **`rm -rf` sempre com trava (`"${VAR:?}"`)** nos scripts que apagam diretórios via variável, pra evitar que uma variável vazia vire um `rm -rf /`.
- **Detectar → avisar → (só então) agir.** Se uma ferramenta ou serviço não existe no sistema, o script avisa e segue (não trava, não assume que existe).
- **Sem systemd/OpenRC reconhecido → aborta com mensagem clara**, em scripts que dependem inteiramente de gerenciamento de serviço (não tenta rodar `systemctl` que não existe).

---

## Instalação

```bash
git clone <url-do-seu-repo> ~/Projects/linux-scripts
cd ~/Projects/linux-scripts
find . -name "*.sh" -exec chmod +x {} \;
```

### (Opcional) Adicionar ao PATH

Diferente da estrutura antiga por distro, agora dá pra expor **todas as categorias de uma vez**, já que não tem mais duplicação por distro:

```bash
# ~/.bashrc ou ~/.zshrc
for dir in ~/Projects/linux-scripts/*/; do
    export PATH="$dir:$PATH"
done
```

```bash
source ~/.bashrc
```

Com isso, qualquer script pode ser chamado de qualquer lugar pelo nome, ex:

```bash
system-health.sh
dev-check.sh
```

---

## Testando antes de confiar

Scripts que só leem o sistema (`*-check.sh`, `*-status.sh`, `system-health.sh`, `hardware-health-check.sh`) são seguros de rodar a qualquer momento.

Scripts que **modificam o sistema como root** (`autofix-system-errors.sh` especialmente, mas também `gaming-install-deps.sh`, `system-update.sh`, `optimize-network.sh`) devem ser testados numa VM ou com um snapshot do sistema de arquivos antes de rodar em produção — principalmente em distros/famílias que você usa com menos frequência.

---

## Compatibilidade conhecida

| Família  | Distros cobertas                          | Nível de confiança                                    |
|----------|--------------------------------------------|--------------------------------------------------------|
| `rhel`   | Fedora, RHEL, CentOS, Rocky, AlmaLinux      | Alto — base original de todos os scripts               |
| `debian` | Debian, Ubuntu                              | Alto — testado ao longo de toda a refatoração          |
| `arch`   | Arch, Manjaro, EndeavourOS                  | Médio — alguns comandos (ex: multilib, distro-sync) não têm equivalente 1:1 e foram documentados como tal |
| `suse`   | openSUSE (Leap/Tumbleweed)                  | Médio — nomes de pacote e alguns comandos (`zypper dup`, Packman) não foram testados ao vivo |
| `alpine` | Alpine Linux                                 | Baixo/experimental — suporte a gaming e multilib é propositalmente limitado; vale testar antes de confiar |

Se algum comando ou nome de pacote estiver errado pra sua distro/versão específica, é normalmente uma mudança pequena e localizada (uma linha no `pkg_name()` ou na lista de candidatos de serviço) — não exige reescrever o script inteiro.

---

## Como adicionar um script novo

1. Escolha a categoria (ou crie uma nova pasta, se for um domínio novo).
2. Copie o bloco de detecção de distro/init de um script existente da mesma categoria.
3. Siga as convenções da seção acima (`set -uo pipefail`, log functions, detectar antes de agir).
4. Se o script mexe em pacotes, use `pkg_name()`/`pkg_install_hint()`. Se mexe em serviços, use o padrão de nomes candidatos (veja `services/*.sh`).
5. Teste pelo menos num ambiente sem systemd/OpenRC (ex: um container mínimo) pra garantir que ele avisa e não quebra, em vez de travar.

---

## Boas práticas gerais

- Nomeie scripts de forma clara e objetiva (verbo + assunto: `clean-user-cache.sh`, `start-services.sh`).
- Comente seções longas; cada script usa uma função `section()` pra separar visualmente as etapas no output.
- Nunca assuma que uma ferramenta existe — sempre `command -v` antes de usar.
- Scripts destrutivos pedem root explicitamente e nunca corrigem "no automático" sem alguma forma de dar pra reverter (backup, log, ou confirmação interativa).