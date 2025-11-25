#!/bin/bash
set -e

# ============================
# Atualização do sistema
# ============================
apt-get update -y
apt-get upgrade -y

# ============================
# Dependências necessárias
# ============================
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git

# ============================
# Repositório oficial do Docker
# ============================
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y

# ============================
# Instalação do Docker Engine + Compose Plugin
# ============================
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker

# ============================
# Adiciona o usuário padrão da AMI ao grupo docker
# (usuário padrão do Debian 12 na AWS = admin)
# ============================
if id "admin" &>/dev/null; then
    usermod -aG docker admin
fi

# ============================
# Clona o repositório da aula
# ============================
cd /home/admin
sudo -u admin git clone https://github.com/Machado-tec/Aula-Observabilidade.git

cd Aula-Observabilidade

# ============================
# Sobe os containers da aula
# ============================
docker compose up -d
