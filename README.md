
# Ubuntu VPS - Instalação de dependências
![Logo](https://i.ibb.co/x8MM6G9N/ubuntulogo.webp) 

Este repositório cumpre o propósito de automatizar a preparação de servidores Ubuntu/Debian recém-instalados.<br> No meu caso de uso da Contabo, ele configura rapidamente um ambiente de produção moderno, pronto para hospedar aplicações web, APIs e painéis de gerenciamento.

## Stack Instalada

* **Pacotes Base:** `curl`, `ca-certificates`, `gnupg`, `lsb-release`, `git`
* **Runtime:** Node.js (versão LTS) e `npm`
* **Gerenciador de Processos:** PM2 (configurado para iniciar automaticamente com o sistema)
* **Servidor Web / Proxy Reverso:** Nginx
* **Banco de Dados NoSQL:** MongoDB (versão 7.0)
* **Banco de Dados em Memória:** Redis
* **Segurança (SSL/TLS):** Certbot e plugin do Nginx

## Como usar

**1. Crie o arquivo:** (ou clone esse repositório)

```bash
nano setup.sh
```

Cole o conteúdo do script dentro do arquivo, salve apertando `Ctrl+O`, `Enter`, e saia com `Ctrl+X`

**2. Atribua permissão de execução ao script:**

```bash
chmod +x setup.sh
```

**3. Execute o script:**
Se você estiver logado como `root`:

```bash
./setup.sh
```

Se estiver usando um usuário comum com privilégios administrativos:

```bash
sudo ./setup.sh
```
O script exibirá ao final um log detalhado em cada etapa.
