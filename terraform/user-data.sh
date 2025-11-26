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
# Clona o repositório do projeto
# ============================
cd /home/admin
sudo -u admin git clone https://github.com/rgiovann/devs2blu-devops-observabilidade.git

cd devs2blu-devops-observabilidade

# ============================
# Remove diretório terraform (não será usado)
# ============================
rm -rf terraform


# ============================
# Garante permissões corretas
# ============================
chown -R admin:admin /home/admin/devs2blu-devops-observabilidade

# ============================
# Sobe os containers do projeto
# ============================
docker compose up -d

# ============================
# Log de conclusão
# ============================
echo "========================================" >> /var/log/user-data.log
echo "Deploy concluído em $(date)" >> /var/log/user-data.log
echo "Projeto: devs2blu-devops-observabilidade" >> /var/log/user-data.log
echo "Containers ativos: $(docker ps --format '{{.Names}}' | wc -l)" >> /var/log/user-data.log
echo "Acesso via HTTPS na porta 443" >> /var/log/user-data.log
echo "========================================" >> /var/log/user-data.log
