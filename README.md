# Guia Prático: Criando e Executando Scripts Linux Customizados

Este guia ensina como criar, organizar e executar scripts personalizados no Linux de forma simples, segura e reutilizável, separando scripts por distribuição.

---

## 1. Estrutura de pastas por distro

Organize seus scripts em pastas por distribuição para manter tudo limpo:

```
~/scripts/
├── maintenance/
│   ├── fedora/
│   │   └── system-update.sh
│   └── ubuntu/
│       └── system-update.sh
```

* `maintenance/`: categoria de scripts de manutenção.
* `fedora/` e `ubuntu/`: scripts específicos para cada distro.
* Cada script deve ser nomeado de forma clara.

Crie as pastas:

```bash
mkdir -p ~/scripts/maintenance/fedora
mkdir -p ~/scripts/maintenance/ubuntu
```

---

## 2. Criar um novo script

Crie o arquivo `.sh` dentro da pasta correspondente à distro. Exemplo com Fedora:

```bash
nano ~/scripts/maintenance/fedora/system-update.sh
```

Exemplo de conteúdo:

```bash
#!/bin/bash

echo "...Atualizando o sistema Fedora..."
sudo dnf update -y
sudo dnf autoremove -y
echo "...Atualização finalizada!"
```

Para Ubuntu, ajuste os comandos (`apt update && apt upgrade -y`).

---

## 3. Tornar o script executável

```bash
chmod +x ~/scripts/maintenance/fedora/system-update.sh
chmod +x ~/scripts/maintenance/ubuntu/system-update.sh
```

---

## 4. Executar o script

Dentro da pasta do script:

```bash
cd ~/scripts/maintenance/fedora
./system-update.sh
```

Ou com caminho completo:

```bash
~/scripts/maintenance/fedora/system-update.sh
```

---

## 5. (Opcional) Tornar scripts globais

Adicione o diretório base ao PATH:

```bash
nano ~/.bashrc
```

Adicione:

```bash
export PATH="$HOME/scripts/maintenance/fedora:$HOME/scripts/maintenance/ubuntu:$PATH"
```

Recarregue:

```bash
source ~/.bashrc
```

Agora é possível executar:

```bash
system-update.sh
```

---

## 6. Boas práticas

* Sempre use `#!/bin/bash` no início do script.
* Nomeie scripts de forma clara e objetiva.
* Separe scripts por distro para evitar erros.
* Comente scripts longos e teste antes de automatizar.
* Adicione novas categorias de scripts criando novas pastas dentro de `~/scripts/`.
