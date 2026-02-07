# Guia: Criando e Executando Scripts Linux Customizados

Este guia explica como criar, organizar e executar scripts personalizados no Linux de forma simples e segura.

---

## 1. Criar a pasta de scripts
Primeiro, crie uma pasta dedicada para seus scripts no diretório pessoal.  
Isso mantém tudo organizado e evita bagunça no sistema.

```bash
mkdir -p ~/scripts
```

- -p: garante que a pasta seja criada mesmo que o caminho não exista.
- ~/scripts: local comum e recomendado para scripts pessoais.
---

## 2.Criar um novo script
Crie o arquivo do script em formato .sh utilizando o editor de texto a sua escolha. No exemplo abaixo, criaremos um script chamado system-update.sh e editado via Nano:

```bash
nano ~/scripts/system-update.sh
```

Dentro do arquivo copie e cole o código do script. Exemplo abaixo:

```bash
#!/bin/bash

echo "...Atualizando o sistema..."
sudo apt update && sudo apt upgrade -y
echo "...Limpando o cache...."
sudo apt autoremove -y
echo "...Atualização finalizada..."
```
---

## 3.Tornar o script executável
Por padrão, arquivos .sh não são executáveis, é necessário alterar as permissões. Abaixo o comando para liberar as permissões:

```bash
sudo chmod +x ~/scripts/system-update.sh
```
Isso permite executar o script .sh dentro da pasta scripts.

---

## 4.Execturar o script
Para rodar o script, basta executar o comando:

```bash
~/scripts/system-update.sh
```

Ou, se estiver dentro da pasta scripts:

```bash
./system-update.sh
```

---

## 5.(Opcional) - Tornar scripts globais
Se quiser rodar seus scripts de qualquer lugar do terminal, adicione a pasta ~/scripts ao PATH do sistema.

```bash
nano ~/.bashrc
```

Adicione ao final do arquivo:

```bash
export PATH="$HOME/scripts:$PATH"
```

Depois recarregue:

```bash
source ~/.bashrc
```

Agora o script pode ser executado apenas com:

```bash
system-update.sh
```

---

## Dicas

Dicas práticas:
- Sempre use #!/bin/bash no inicio do script.
- Nomeie scripts de forma clara como no exemplo utilizado.
- Crie comentários em scripts longos e detalhados.
- Teste sempre antes de automatizer e incluir no PATH.



