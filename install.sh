#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Configuração e instalação de dependências${NC}"
echo -e "${BLUE}==========================================${NC}"

if ! command -v apt >/dev/null 2>&1; then
  echo -e "${RED}[x] Erro: Este script suporta apenas ambientes Ubuntu/Debian com apt.${NC}"
  exit 1
fi

UPDATED_APT=0
MONGO_REPO_CONFIGURED=0

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
  EFFECTIVE_USER="root"
  EFFECTIVE_HOME="/root"
  echo -e "${BLUE}[i] Executando em modo root (compatível com VPS nova da Contabo).${NC}"
else
  SUDO="sudo"
  EFFECTIVE_USER="${USER}"
  EFFECTIVE_HOME="${HOME}"
  echo -e "${BLUE}[i] Executando como ${EFFECTIVE_USER} com sudo.${NC}"
fi

ensure_apt_update() {
  if [[ "${UPDATED_APT}" -eq 0 ]]; then
    echo ""
    echo -e "${BLUE}[apt] Atualizando lista de pacotes...${NC}"
    ${SUDO} apt update -qq
    UPDATED_APT=1
  fi
}

ensure_package() {
  local package_name="$1"

  if dpkg -s "${package_name}" >/dev/null 2>&1; then
    echo -e "${GREEN}[-] ${package_name} já instalado${NC}"
    return
  fi

  ensure_apt_update
  echo -e "${BLUE}[+] Instalando ${package_name}...${NC}"
  ${SUDO} apt install -y "${package_name}" >/dev/null
}

ensure_service_running() {
  local service_name="$1"

  ${SUDO} systemctl enable "${service_name}" >/dev/null 2>&1 || true

  if ${SUDO} systemctl is-active --quiet "${service_name}"; then
    echo -e "${GREEN}[-] ${service_name} já está rodando${NC}"
    return
  fi

  echo -e "${BLUE}[+] Iniciando ${service_name}...${NC}"
  ${SUDO} systemctl start "${service_name}"
}

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo -e "${GREEN}[-] Node.js $(node -v) e npm $(npm -v) já instalados${NC}"
    return
  fi

  echo -e "${BLUE}[+] Instalando Node.js LTS...${NC}"
  if [[ "${EUID}" -eq 0 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1
  else
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
  fi
  ensure_apt_update
  ${SUDO} apt install -y nodejs >/dev/null
  echo -e "${GREEN}[ok] Node.js $(node -v) e npm $(npm -v) instalados${NC}"
}

ensure_pm2() {
  if command -v pm2 >/dev/null 2>&1; then
    echo -e "${GREEN}[-] PM2 $(pm2 -v) já instalado${NC}"
  else
    echo -e "${BLUE}[+] Instalando PM2...${NC}"
    ${SUDO} npm install -g pm2 >/dev/null 2>&1
  fi

  if ! ${SUDO} systemctl list-unit-files | grep -q "pm2-${EFFECTIVE_USER}.service"; then
    echo -e "${BLUE}[+] Configurando inicialização do PM2...${NC}"
    env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u "${EFFECTIVE_USER}" --hp "${EFFECTIVE_HOME}" >/dev/null 2>&1
    pm2 save >/dev/null 2>&1
  else
    echo -e "${GREEN}[-] Inicialização do PM2 já configurada${NC}"
  fi
}

ensure_mongodb_repo() {
  if [[ "${MONGO_REPO_CONFIGURED}" -eq 1 ]]; then
    return
  fi

  if [[ ! -f /usr/share/keyrings/mongodb-server-7.0.gpg ]]; then
    echo -e "${BLUE}[+] Adicionando chave de assinatura do MongoDB...${NC}"
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | ${SUDO} gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
  else
    echo -e "${GREEN}[-] Chave de assinatura do MongoDB já presente${NC}"
  fi

  if [[ ! -f /etc/apt/sources.list.d/mongodb-org-7.0.list ]]; then
    echo -e "${BLUE}[+] Adicionando repositório do MongoDB...${NC}"
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
    UPDATED_APT=0
  else
    echo -e "${GREEN}[-] Repositório do MongoDB já configurado${NC}"
  fi

  MONGO_REPO_CONFIGURED=1
}

echo ""
echo -e "${BLUE}[1/6] Pacotes base${NC}"
ensure_package curl
ensure_package ca-certificates
ensure_package gnupg
ensure_package lsb-release
ensure_package git

echo ""
echo -e "${BLUE}[2/6] Node.js e npm${NC}"
ensure_node

echo ""
echo -e "${BLUE}[3/6] Nginx e Certbot${NC}"
ensure_package nginx
ensure_service_running nginx
ensure_package certbot
ensure_package python3-certbot-nginx

echo ""
echo -e "${BLUE}[4/6] PM2${NC}"
ensure_pm2

echo ""
echo -e "${BLUE}[5/6] MongoDB${NC}"
ensure_mongodb_repo
ensure_apt_update
ensure_package mongodb-org
ensure_service_running mongod

echo ""
echo -e "${BLUE}[6/6] Redis${NC}"
ensure_package redis-server
ensure_service_running redis-server

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}[ok] Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${BLUE}Versões instaladas:${NC}"
echo "  Node.js: $(node -v)"
echo "  npm: $(npm -v)"
echo "  Git: $(git --version | awk '{print $3}')"
echo "  nginx: $(nginx -v 2>&1 | cut -d'/' -f2)"
echo "  PM2: $(pm2 -v)"
echo "  MongoDB: $(mongod --version | head -n1 | awk '{print $3}')"
echo "  Redis: $(redis-server --version | awk -F'=' '{print $2}' | awk '{print $1}')"
echo ""
echo -e "${BLUE}Status dos serviços:${NC}"
${SUDO} systemctl is-active --quiet nginx && echo -e "  ${GREEN}[ok] nginx${NC}" || echo -e "  ${RED}[x] nginx${NC}"
${SUDO} systemctl is-active --quiet mongod && echo -e "  ${GREEN}[ok] mongod${NC}" || echo -e "  ${RED}[x] mongod${NC}"
${SUDO} systemctl is-active --quiet redis-server && echo -e "  ${GREEN}[ok] redis-server${NC}" || echo -e "  ${RED}[x] redis-server${NC}"
echo ""
echo -e "${YELLOW}Comandos úteis:${NC}"
echo "  sudo certbot --nginx"
echo "  sudo systemctl status nginx"
echo "  sudo systemctl status mongod"
echo "  sudo systemctl status redis-server"
echo "  pm2 list"
