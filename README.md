# Observabilidade com Containers

Este diretório reúne o ambiente prático para instrumentar um host Linux usando containers: exporters (sistema operacional, ping e banco de dados), Prometheus, Grafana, banco de dados MariaDB com gerador de carga e Nginx como reverse proxy com autenticação. A ideia é construir cada componente em etapas curtas, sempre validando antes de avançar.

## Visão geral

- **Exporter do sistema operacional**: container baseado em `prom/node-exporter` expondo métricas do host (CPU, memória, disco, rede) na porta 9100.
- **Ping exporter**: `czerwonk/ping_exporter` medindo latência/perda para alvos críticos (roteador 192.168.1.1 e Google 8.8.8.8). Porta 9427.
- **MariaDB**: banco de dados relacional para simular carga de aplicação. Porta 3306.
- **MariaDB Exporter**: `prom/mysqld-exporter` coletando métricas do banco (queries, threads, buffer pool). Porta 9104.
- **Load Generator**: gerador de carga sintética inserindo dados continuamente no MariaDB.
- **Prometheus**: servidor de coleta configurado para fazer scrape dos exporters. Porta 9090.
- **Alertmanager**: gerenciador de alertas integrado ao Prometheus. Porta 9093.
- **Grafana**: interface para dashboards/alertas consumindo o Prometheus como data source. Porta 3000 (interna).
- **Nginx**: reverse proxy com SSL/TLS e autenticação básica protegendo o acesso ao Grafana. Porta 443 (HTTPS).
- **Orquestração**: Docker Compose simples que liga todo o stack com redes/volumes mínimos.

## Estrutura do projeto

```
obs/
├── alertmanager/           # Configuração do Alertmanager
├── db/                     # Dockerfile e scripts de inicialização do MariaDB
├── exporter/               # Dockerfile + configs do Node Exporter
│   └── config/
├── exporter-db/            # Dockerfile e credenciais do MariaDB Exporter
├── grafana/                # Provisão de datasources/dashboards
│   ├── dashboards/
│   └── provisioning/
│       ├── dashboards/
│       └── datasources/
├── load-generator/         # Gerador de carga para o MariaDB
├── nginx/                  # Reverse proxy com SSL e autenticação
│   └── ssl/
├── ping-exporter/          # ping_exporter.yml com destinos/intervalos
├── prometheus/             # prometheus.yml, rules, data dir
│   ├── data/
│   └── rules/
├── terraform/              # Infraestrutura como código (AWS)
└── docker-compose.yml      # Orquestra todo o stack
```

## Fluxo proposto

### Etapa 1 – Exporter do sistema operacional

- Criar `exporter/Dockerfile` configurando `prom/node-exporter`.
- Definir `exporter/config/entrypoint.sh` com flags (textfile collector, path /host etc.).
- Validar localmente: `docker compose up exporter` e `curl http://localhost:9100/metrics`.

### Etapa 2 – Banco de dados e exporter

- Criar `db/Dockerfile` configurando MariaDB com usuários e banco inicial.
- Scripts SQL (`init.sql`, `exporter-user.sql`) para criar tabela de healthcheck e usuário do exporter.
- Criar `exporter-db/Dockerfile` e `.my.cnf` para o mysqld-exporter.
- Validar: `docker compose up db db-exporter` e `curl http://localhost:9104/metrics`.

### Etapa 3 – Gerador de carga

- Criar `load-generator/Dockerfile` e `load.sh` para inserir dados continuamente no MariaDB.
- Validar: logs do container devem mostrar inserções periódicas sem erros.

### Etapa 4 – Prometheus + Ping exporter + Alertmanager

- Criar `prometheus/prometheus.yml` com os jobs `node-exporter`, `ping-exporter` e `mariadb_exporter`.
- Definir `ping-exporter/ping_exporter.yml` com destinos (roteador da rede e Google) e intervalos.
- Configurar `alertmanager/alertmanager.yml` para roteamento de alertas.
- Adicionar armazenamento (volume) e regras de alertas iniciais em `prometheus/rules/`.
- Validar consultas no console: `node_cpu_seconds_total`, `node_memory_*`, `ping_rtt_mean_seconds{alias="router"}`, `mysql_global_status_queries`.

### Etapa 5 – Grafana

- Provisionar datasource (`grafana/provisioning/datasources/prometheus.yml`).
- Provisionar dashboards prontos: Node Exporter e MariaDB Overview.
- Garantir autenticação básica e persistência (admin/admin → alterar senha).

### Etapa 6 – Nginx (reverse proxy com SSL)

- Criar `nginx/Dockerfile` e `default.conf` configurando proxy reverso para Grafana.
- Gerar certificados SSL autoassinados (`cert.pem`, `key.pem`) em `nginx/ssl/`.
- Configurar autenticação básica com `.htpasswd` (usuário: admin, senha: admin2025).
- Validar: acesso via `https://localhost` deve solicitar autenticação e redirecionar para o Grafana.

### Etapa 7 – Compose final

- Montar `docker-compose.yml` incluindo todos os serviços.
- Scripts utilitários (make up, make down, etc.) se necessário.

## Componentes detalhados

### Exporter (Node Exporter)

#### Build da imagem

```bash
cd obs
docker build -t obs-node-exporter ./exporter
```

A imagem inclui o script `entrypoint.sh` que aplica as flags padrão e aceita variáveis extras via `NODE_EXPORTER_FLAGS`.

#### Executar localmente (modo standalone)

```bash
docker run --rm \
  --name node-exporter \
  -p 9100:9100 \
  -v /:/host:ro,rslave \
  obs-node-exporter
```

O bind em `/host` garante que o exporter enxergue o filesystem real.

#### Validar

```bash
curl http://localhost:9100/metrics | head
```

Procure por `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_filesystem_*`.

### MariaDB

#### Arquivos relevantes

- `db/Dockerfile`: baseado em `mariadb:11` com variáveis de ambiente para criar banco e usuários.
- `db/init.sql`: cria tabela `healthcheck` para o gerador de carga.
- `db/exporter-user.sql`: cria usuário `exporter` com permissões mínimas para coleta de métricas.

#### Executar

```bash
docker compose up db
```

Banco disponível na porta 3306 com:
- Root: `root/root`
- Aplicação: `appuser/apppass` (banco `appdb`)
- Exporter: `exporter/exporterpass`

### MariaDB Exporter

#### Arquivos relevantes

- `exporter-db/Dockerfile`: baseado em `prom/mysqld-exporter:v0.15.1`.
- `exporter-db/.my.cnf`: credenciais para conexão ao MariaDB.

#### Validar

```bash
curl http://localhost:9104/metrics | grep mysql_global_status
```

Métricas: `mysql_global_status_queries`, `mysql_global_status_threads_running`, `mysql_global_status_innodb_buffer_pool_bytes_data`.

### Load Generator

#### Arquivos relevantes

- `load-generator/Dockerfile`: Alpine com `mariadb-client`.
- `load-generator/load.sh`: loop infinito inserindo registros na tabela `healthcheck` a cada 300ms.

#### Executar

```bash
docker compose up load-generator
```

Validar logs: devem aparecer inserções periódicas sem erros de conexão.

### Prometheus

#### Arquivos relevantes

- `prometheus/Dockerfile`: constrói imagem baseada em `prom/prometheus:v2.51.2`.
- `prometheus/prometheus.yml`: define `scrape_configs` para `node-exporter:9100`, `ping-exporter:9427`, `db-exporter:9104`.
- `prometheus/rules/node-alerts.yml`: exemplo de alerta (`NodeExporterDown`).
- `prometheus/data/`: diretório para persistir TSDB.

#### Build e execução

```bash
docker build -t obs-prometheus ./prometheus
docker compose up prometheus
```

#### Validar no console

Acesse `http://localhost:9090` e execute queries:
- `up{job="node-exporter"}` (deve retornar 1)
- `rate(node_cpu_seconds_total{mode="system"}[5m])`
- `mysql_global_status_queries`
- `ping_rtt_mean_seconds{alias="router"}`

### Ping Exporter

#### Arquivo relevante

- `ping-exporter/ping_exporter.yml`: define alvos (192.168.1.1 como router, 8.8.8.8 como google), intervalo de 5s, timeout e payload.

#### Validar

```bash
curl http://localhost:9427/metrics | grep ping_rtt_mean_seconds
```

Métricas: `ping_rtt_mean_seconds`, `ping_rtt_best_seconds`, `ping_rtt_worst_seconds`, `ping_loss_ratio`, `ping_up`.

### Alertmanager

#### Arquivo relevante

- `alertmanager/alertmanager.yml`: configuração básica com receiver padrão.

#### Executar

```bash
docker compose up alertmanager
```

Interface disponível em `http://localhost:9093`.

### Grafana

#### Arquivos relevantes

- `grafana/Dockerfile`: baseado em `grafana/grafana:10.4.2`, copia provisioning e dashboards.
- `grafana/provisioning/datasources/prometheus.yml`: cria datasource apontando para `http://prometheus:9090`.
- `grafana/provisioning/dashboards/dashboard.yml`: aponta para `/var/lib/grafana/dashboards`.
- `grafana/dashboards/node-exporter-overview.json`: painel com CPU, memória, disco /, processos, rede e latências de ping.
- `grafana/dashboards/mariadb-overview.json`: painel com QPS, threads, buffer pool, slow queries, conexões e bytes recebidos.

#### Primeiro acesso (via Nginx)

Navegue até `https://localhost` (ou IP público na AWS).
- Autenticação Nginx: `admin / admin2025`
- Login Grafana: `admin / admin` (altere a senha imediatamente)

Datasource Prometheus aparece como default. Dashboards disponíveis em **Dashboards → Observabilidade**:
- Node Exporter – Visão rápida
- MariaDB Overview

### Nginx (Reverse Proxy)

#### Arquivos relevantes

- `nginx/Dockerfile`: baseado em `nginx:alpine`, copia `default.conf`.
- `nginx/default.conf`: configura HTTPS (porta 443), SSL, autenticação básica e proxy para `http://grafana:3000`.
- `nginx/.htpasswd`: arquivo de senhas (usuário `admin`, senha `admin2025`).
- `nginx/ssl/cert.pem` e `nginx/ssl/key.pem`: certificados SSL autoassinados.

#### Gerar certificados SSL (se necessário)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/CN=localhost"
```

#### Executar

```bash
docker compose up nginx
```

Acesse `https://localhost` e informe credenciais quando solicitado.

**Importante**: o Nginx remove o cabeçalho `Authorization` antes de encaminhar para o Grafana (`proxy_set_header Authorization "";`), garantindo que a autenticação básica do Nginx não interfira no login do Grafana.

## Compose completo

Execute o stack inteiro:

```bash
docker compose up -d
```

Use `docker compose down` para encerrar todos os serviços.

Como as pastas `grafana/provisioning` e `grafana/dashboards` são montadas, qualquer alteração local reflete após `docker compose restart grafana`.

## Terraform (Infraestrutura AWS)

O diretório `terraform/` contém código para provisionar uma instância EC2 (Debian 12, t3.small) com:
- Security group permitindo SSH (22) e HTTPS (443)
- User data que instala Docker, clona o repositório e sobe o stack via `docker compose`
- Outputs com IP público, URL de acesso e comando SSH

### Executar Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Após o apply, o output mostrará:
- `ec2_public_ip`: IP público da instância
- `access_url`: `https://<IP>`
- `ssh_command`: comando para conectar via SSH
- `credentials`: `admin / admin2025` (sensível, use `-json` ou `terraform output credentials`)

Acesse `https://<IP>` no navegador e informe as credenciais do Nginx.

## Checklist de implementação

- [x] Criar diretório `exporter/` com Dockerfile e config/.
- [x] Escrever instruções de build/run para o exporter no README.
- [x] Criar diretório `db/` com Dockerfile e scripts SQL.
- [x] Criar diretório `exporter-db/` com Dockerfile e credenciais.
- [x] Criar diretório `load-generator/` com script de carga.
- [x] Criar diretório `prometheus/` com prometheus.yml e rules/.
- [x] Documentar como iniciar o Prometheus isoladamente e validar métricas.
- [x] Criar diretório `ping-exporter/` com configuração de alvos.
- [x] Criar diretório `alertmanager/` com configuração básica.
- [x] Criar diretório `grafana/` com provisioning de datasource e dashboards (Node Exporter + MariaDB).
- [x] Criar diretório `nginx/` com SSL e autenticação básica.
- [x] Registrar passo a passo para configurar SSL e acesso via Nginx.
- [x] Escrever `docker-compose.yml` conectando todos os serviços.
- [x] Criar diretório `terraform/` com infraestrutura AWS.
- [x] Validar fluxo completo: exporters → Prometheus → Grafana (via Nginx) com dashboards.

## Como pedir os próximos passos

A cada item marcado acima, solicite a criação do arquivo correspondente (por exemplo: "crie o Dockerfile do exporter"). Eu responderei com o conteúdo, explicarei como validar e atualizarei este README se necessário.

## Métricas importantes

### Node Exporter
- `node_cpu_seconds_total`: tempo de CPU por modo (idle, system, user)
- `node_memory_MemAvailable_bytes` / `node_memory_MemTotal_bytes`: uso de memória
- `node_filesystem_avail_bytes` / `node_filesystem_size_bytes`: uso de disco
- `node_network_receive_bytes_total`, `node_network_transmit_bytes_total`: tráfego de rede

### Ping Exporter
- `ping_rtt_mean_seconds{alias="router"}`: latência média para o roteador
- `ping_rtt_mean_seconds{alias="google"}`: latência média para o Google
- `ping_loss_ratio`: taxa de perda de pacotes
- `ping_up`: disponibilidade do alvo (1 = up, 0 = down)

### MariaDB Exporter
- `mysql_global_status_queries`: total de queries executadas
- `mysql_global_status_threads_running`: threads executando queries
- `mysql_global_status_threads_connected`: conexões ativas
- `mysql_global_status_innodb_buffer_pool_bytes_data`: uso do buffer pool InnoDB
- `mysql_global_status_slow_queries`: queries lentas
- `mysql_global_status_bytes_received`: bytes recebidos pelo servidor

## Troubleshooting

### Prometheus não coleta métricas do exporter
- Verifique se os containers estão na mesma rede: `docker network inspect obs_default`
- Valide a resolução DNS: `docker compose exec prometheus ping exporter`
- Confira logs: `docker compose logs prometheus`

### Grafana não exibe dados
- Verifique se o datasource Prometheus está configurado e acessível (Settings → Data sources)
- Teste queries manualmente no Prometheus (`http://localhost:9090`)
- Confirme que o intervalo de tempo no dashboard não está muito no passado

### MariaDB Exporter retorna erro de conexão
- Confirme que o usuário `exporter` foi criado com as permissões corretas
- Valide credenciais em `exporter-db/.my.cnf`
- Teste conexão manual: `docker compose exec db-exporter mysql -h db -u exporter -pexporterpass -e "SELECT 1"`

### Nginx retorna erro de certificado
- Navegadores modernos bloqueiam certificados autoassinados. Aceite a exceção de segurança ou gere certificados válidos (Let's Encrypt)
- Para produção, use certificados de uma CA confiável

### Load Generator não insere dados
- Verifique logs: `docker compose logs load-generator`
- Confirme que o banco `appdb` e tabela `healthcheck` existem
- Teste conexão: `docker compose exec load-generator mysql -h db -u appuser -papppass appdb -e "SELECT COUNT(*) FROM healthcheck"`

## Próximos passos sugeridos

1. **Alertas avançados**: configurar regras de alerta para CPU alta, memória baixa, slow queries, latência de rede elevada
2. **Alertmanager integrado**: configurar receivers (Slack, email, PagerDuty)
3. **Dashboards adicionais**: criar painéis para análise de tendências, capacidade, SLOs
4. **Exporters adicionais**: adicionar cAdvisor (métricas de containers), Blackbox Exporter (monitoramento de endpoints HTTP)
5. **Automação**: scripts para backup de dashboards, rotação de dados do Prometheus, healthchecks
6. **Segurança**: substituir certificados autoassinados, rotacionar senhas, habilitar TLS no Prometheus/Grafana
7. **High Availability**: replicar Prometheus, configurar Grafana com banco externo, load balancer para Nginx