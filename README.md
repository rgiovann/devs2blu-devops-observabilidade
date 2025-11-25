# Observabilidade com Containers

Este diretório reúne o ambiente prático para instrumentar um host Linux usando containers: primeiro o exporter do sistema operacional, depois o Prometheus e por fim o Grafana. A ideia é construir cada componente em etapas curtas, sempre validando antes de avançar.

## Visão geral
- **Exporter do sistema operacional**: container baseado em `prom/node-exporter` expondo métricas do host (CPU, memória, disco, rede) na porta 9100.
- **Ping exporter**: `czerwonk/ping_exporter` medindo latência/perda para alvos críticos (roteador `192.168.1.1` e Google `8.8.8.8`). Porta 9427.
- **Prometheus**: servidor de coleta configurado para fazer scrape do exporter, ping exporter e demais serviços. Porta 9090.
- **Grafana**: interface para dashboards/alertas consumindo o Prometheus como data source. Porta 3000.
- **Orquestração**: Docker Compose simples que liga todo o stack com redes/volumes mínimos.

## Estrutura sugerida
```
obs/
├── exporter/           # Dockerfile + configs do Node Exporter
├── ping-exporter/      # ping_exporter.yml com destinos/intervalos
├── prometheus/         # prometheus.yml, rules, data dir
├── grafana/            # provisão de datasources/dashboards
└── docker-compose.yml  # orquestra exporter + ping + Prometheus + Grafana
```

## Fluxo proposto
1. **Etapa 1 – Exporter**
   - Criar `exporter/Dockerfile` configurando `prom/node-exporter`.
   - Definir `exporter/config` com flags (textfile collector, path /host etc.).
   - Validar localmente: `docker compose up exporter` e `curl http://localhost:9100/metrics`.
2. **Etapa 2 – Prometheus + Ping exporter**
   - Criar `prometheus/prometheus.yml` com os jobs `node-exporter` e `ping-exporter`.
   - Definir `ping-exporter/ping_exporter.yml` com destinos (roteador da rede e Google) e intervalos.
   - Adicionar armazenamento (volume) e regras de alertas iniciais.
   - Validar consultas no console: `node_cpu_seconds_total`, `node_memory_*`, `ping_rtt_mean_seconds{alias="router"}`.
3. **Etapa 3 – Grafana**
   - Provisionar datasource (`grafana/provisioning/datasources/prometheus.yml`).
   - (Opcional) Provisionar dashboards prontos (dashboard 1860) ou custom simples.
   - Garantir autenticação básica e persistência (admin/admin → alterar senha).
4. **Etapa 4 – Compose final**
   - Montar `docker-compose.yml` incluindo exporter, ping exporter, Prometheus e Grafana.
   - Scripts utilitários (`make up`, `make down`, etc.) se necessário.

## Exporter – como construir e executar
1. **Build da imagem**
   ```bash
   cd obs
   docker build -t obs-node-exporter ./exporter
   ```
   - A imagem inclui o script `entrypoint.sh` que aplica as flags padrão e aceita variáveis extras via `NODE_EXPORTER_FLAGS`.
2. **Executar localmente (modo standalone)**
   ```bash
   docker run --rm \
     --name node-exporter \
     -p 9100:9100 \
     -v /:/host:ro,rslave \
     obs-node-exporter
   ```
   - O bind em `/host` garante que o exporter enxergue o filesystem real.
   - Para coletar métricas adicionais (ex.: textfile collector), monte diretórios extras: `-v $(pwd)/exporter/textfile:/etc/node-exporter/textfile`.
3. **Validar**
   ```bash
   curl http://localhost:9100/metrics | head
   ```
   - Procure por `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_filesystem_*`.
4. **Usar Docker Compose (apenas exporter)**
   ```bash
   docker compose up exporter
   ```
   - Compose utiliza o `docker-compose.yml` na raiz de `obs/`, construindo a imagem e montando `/host` automaticamente.

## Prometheus – configuração e execução isolada
1. **Arquivos relevantes**
   - `prometheus/Dockerfile`: constrói a imagem baseada em `prom/prometheus:v2.51.2` copiando `prometheus.yml` e `rules/`.
   - `prometheus/prometheus.yml`: define `scrape_configs` (`exporter:9100` + `ping-exporter:9427`).
   - `prometheus/rules/node-alerts.yml`: exemplo de alerta (`NodeExporterDown`).
   - `prometheus/data/`: diretório sugerido para persistir a TSDB quando rodar via `docker run`.
2. **Build da imagem**
   ```bash
   cd obs
   docker build -t obs-prometheus ./prometheus
   ```
   - Sempre que alterar `prometheus.yml` ou `rules/`, execute um novo build.
3. **Executar manualmente (precisa do exporter/ping-exporter ativos e da rede do Compose)**
   ```bash
   docker compose up -d exporter ping-exporter  # garante rede obs_default e métricas de host + ping
   docker run --rm \
     --name prometheus \
     --network obs_default \
     -p 9090:9090 \
     -v $(pwd)/prometheus/data:/prometheus \
     obs-prometheus
   ```
   - O `--network obs_default` permite resolver `exporter:9100` e `ping-exporter:9427`, definidos no `prometheus.yml`.
   - Certifique-se de que `prometheus/data/` tem permissão de escrita (ex.: `chmod 777 prometheus/data`).
4. **Validar no console**
   - Acesse `http://localhost:9090` e execute as queries:
     - `up{job="node-exporter"}` (deve retornar `1`).
     - `rate(node_cpu_seconds_total{mode="system"}[5m])`
     - `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes`
     - `ping_rtt_mean_seconds{alias="router"}` e `ping_rtt_mean_seconds{alias="google"}`
   - Verifique a aba *Alerts* para observar o alerta `NodeExporterDown` (deve estar em estado *Inactive* quando tudo ok).
5. **Usar Docker Compose (exporter + ping + Prometheus)**
   ```bash
   docker compose up prometheus
   ```
   - O Compose constrói a imagem automaticamente, conecta nos exporters e usa o volume nomeado `prometheus-data` para persistência.

## Ping exporter – latência e disponibilidade da rede
1. **Arquivo relevante**
   - `ping-exporter/ping_exporter.yml`: define os alvos (`192.168.1.1` identificado como `router` e `8.8.8.8` como `google`), bem como intervalo (`5s`), timeout e payload.
2. **Executar isoladamente**
   ```bash
   cd obs
   docker compose up ping-exporter
   ```
   - O container precisa de `CAP_NET_RAW` para enviar ICMP (já configurado no Compose).
3. **Validar**
   - `curl http://localhost:9427/metrics | grep ping_rtt_mean_seconds`
   - Métricas: `ping_rtt_mean_seconds`, `ping_rtt_best_seconds`, `ping_rtt_worst_seconds`, `ping_loss_ratio`, `ping_up`.
4. **Ajustes comuns**
   - Edite o YAML para incluir outros destinos ou alterar o intervalo de coleta. Use o campo `alias` para definir um rótulo amigável (usado nos painéis Grafana).
   - O exporter observa o arquivo via inotify e recarrega sozinho, mas reiniciar o serviço garante aplicação imediata.

## Grafana – dashboard inicial e autenticação
1. **Arquivos relevantes**
   - `grafana/Dockerfile`: baseado em `grafana/grafana:10.4.2`, copia a pasta de provisioning.
   - `grafana/provisioning/datasources/prometheus.yml`: cria o datasource apontando para `http://prometheus:9090` e marca como default.
   - `grafana/provisioning/dashboards/dashboard.yml`: aponta para `/var/lib/grafana/dashboards`.
   - `grafana/dashboards/node-exporter-overview.json`: painel com CPU, memória, disco `/`, processos, tráfego de rede e latências de ping (roteador/Google).
2. **Build da imagem**
   ```bash
   cd obs
   docker build -t obs-grafana ./grafana
   ```
3. **Executar manualmente (usa mesma rede do Compose)**
   ```bash
   docker compose up -d prometheus ping-exporter  # garante exporters + Prometheus
   docker run --rm \
     --name grafana \
     --network obs_default \
     -p 3000:3000 \
     -e GF_SECURITY_ADMIN_USER=admin \
     -e GF_SECURITY_ADMIN_PASSWORD=admin \
     -e GF_USERS_ALLOW_SIGN_UP=false \
     -v grafana-data:/var/lib/grafana \
     -v $(pwd)/grafana/provisioning:/etc/grafana/provisioning:ro \
     -v $(pwd)/grafana/dashboards:/var/lib/grafana/dashboards:ro \
     obs-grafana
   ```
   - O volume nomeado `grafana-data` pode ser criado previamente (`docker volume create grafana-data`).
4. **Primeiro acesso**
   - Navegue até `http://localhost:3000` e faça login com `admin/admin` (altere a senha imediatamente).
   - O datasource Prometheus deve aparecer como *default* em *Connections → Data sources*.
   - O dashboard “Node Exporter – Visão rápida” aparece em *Dashboards → Observabilidade* com painéis para CPU, memória, disco `/`, processos, rede (RX/TX) e latência de ping dos dois alvos.
5. **Usar Docker Compose (stack completa)**
   ```bash
   docker compose up grafana
   ```
   - Sobe exporter, ping exporter, Prometheus e Grafana. Use `-d` para rodar em background e `docker compose down` para encerrar. Como as pastas `grafana/provisioning` e `grafana/dashboards` são montadas dentro do container, qualquer alteração local reflete após `docker compose restart grafana`.

## Checklist de implementação
- [x] Criar diretório `exporter/` com Dockerfile e `config/`.
- [x] Escrever instruções de build/run para o exporter no README.
- [x] Criar diretório `prometheus/` com `prometheus.yml` e (opcional) `rules/`.
- [x] Documentar como iniciar o Prometheus isoladamente e validar as métricas.
- [x] Criar diretório `grafana/` com provisioning de datasource e dashboards.
- [x] Registrar passo a passo para configurar usuário/senha inicial do Grafana.
- [x] Escrever `docker-compose.yml` conectando exporter, Prometheus e Grafana.
- [ ] Adicionar comandos de conveniência (scripts/Makefile) para subir e derrubar o stack.
- [ ] Validar fluxo completo: exporter → Prometheus → Grafana com dashboard básico.

## Como pedir os próximos passos
A cada item marcado acima, solicite a criação do arquivo correspondente (por exemplo: “crie o Dockerfile do exporter”). Eu responderei com o conteúdo, explicarei como validar e atualizarei este README se necessário.
