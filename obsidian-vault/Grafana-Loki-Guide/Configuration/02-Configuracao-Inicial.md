# ⚙️ Configuração Inicial Avançada do Grafana Loki

> **Tempo estimado:** 30-45 minutos  
> **Dificuldade:** Intermediário  
> **Pré-requisitos:** Instalação básica concluída

## 📋 Visão Geral

Neste guia, você aprenderá a configurar o Grafana Loki de forma mais avançada, incluindo:

- **Otimização de performance**
- **Configuração de retenção de logs**
- **Configuração de alertas**
- **Dashboards personalizados**
- **Configurações de segurança básica**

---

## 🔧 Passo 1: Configuração Avançada do Loki

### 1.1 Backup da Configuração Atual

```bash
cd ~/loki-stack
cp config/loki/loki-config.yml config/loki/loki-config.yml.backup
```

### 1.2 Configuração Otimizada do Loki

```bash
cat > ~/loki-stack/config/loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

# Configurações de ingestão
ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  max_transfer_retries: 0
  wal:
    enabled: true
    dir: /loki/wal

# Configurações de consulta
querier:
  query_timeout: 1m
  tail_max_duration: 1h

query_range:
  align_queries_with_step: true
  max_retries: 5
  split_queries_by_interval: 15m
  cache_results: true
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 500
        ttl: 1h

# Configurações de schema
schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

# Configurações de armazenamento
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

# Configurações de compactação
compactor:
  working_directory: /loki/boltdb-shipper-compactor
  shared_store: filesystem

# Configurações de limites
limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 6
  max_query_parallelism: 32
  max_streams_per_user: 10000
  max_line_size: 256000
  retention_period: 744h  # 31 dias

# Configurações de chunk
chunk_store_config:
  max_look_back_period: 0s

# Configurações de tabela
table_manager:
  retention_deletes_enabled: true
  retention_period: 744h  # 31 dias

# Configurações de ruler (alertas)
ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /loki/rules
  alertmanager_url: http://alertmanager:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
  enable_alertmanager_v2: true

# Configurações de frontend
frontend:
  log_queries_longer_than: 5s
  compress_responses: true

# Configurações de frontend worker
frontend_worker:
  frontend_address: 127.0.0.1:9095
  parallelism: 10
  match_max_concurrent: true

# Configurações de analytics (desabilitado para privacidade)
analytics:
  reporting_enabled: false
EOF
```

---

## 📊 Passo 2: Configuração Avançada do Promtail

### 2.1 Configuração Otimizada do Promtail

```bash
cat > ~/loki-stack/config/promtail/promtail-config.yml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0
  log_level: info

positions:
  filename: /tmp/positions.yaml
  sync_period: 10s

clients:
  - url: http://loki:3100/loki/api/v1/push
    batchwait: 1s
    batchsize: 1048576
    timeout: 10s
    backoff_config:
      min_period: 500ms
      max_period: 5m
      max_retries: 10

scrape_configs:
  # Logs do sistema
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: ${HOSTNAME}
          __path__: /var/log/*.log
    pipeline_stages:
      - match:
          selector: '{job="varlogs"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\S+\s+\S+\s+\S+)\s+(?P<hostname>\S+)\s+(?P<service>\S+):\s+(?P<message>.*)$'
            - labels:
                service:
                hostname:
            - timestamp:
                source: timestamp
                format: Jan 02 15:04:05

  # Logs do syslog
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          host: ${HOSTNAME}
          __path__: /var/log/syslog
    pipeline_stages:
      - match:
          selector: '{job="syslog"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\S+\s+\S+\s+\S+)\s+(?P<hostname>\S+)\s+(?P<service>\S+)(\[(?P<pid>\d+)\])?\:\s+(?P<message>.*)$'
            - labels:
                service:
                hostname:
                pid:
            - timestamp:
                source: timestamp
                format: Jan 02 15:04:05

  # Logs de autenticação
  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          host: ${HOSTNAME}
          __path__: /var/log/auth.log
    pipeline_stages:
      - match:
          selector: '{job="auth"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\S+\s+\S+\s+\S+)\s+(?P<hostname>\S+)\s+(?P<service>\S+)(\[(?P<pid>\d+)\])?\:\s+(?P<message>.*)$'
            - labels:
                service:
                hostname:
                pid:
            - timestamp:
                source: timestamp
                format: Jan 02 15:04:05

  # Logs do Docker
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: ${HOSTNAME}
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag: attrs.tag
          source: attrs
      - regex:
          expression: '^/var/lib/docker/containers/(?P<container_id>[^/]+)/.*$'
          source: filename
      - labels:
          container_id:
          stream:
          tag:
      - output:
          source: output

  # Logs personalizados
  - job_name: custom
    static_configs:
      - targets:
          - localhost
        labels:
          job: custom
          host: ${HOSTNAME}
          __path__: /logs/*.log
    pipeline_stages:
      - match:
          selector: '{job="custom"}'
          stages:
            - multiline:
                firstline: '^\d{4}-\d{2}-\d{2}'
                max_wait_time: 3s
            - regex:
                expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(?P<level>\w+)\s+(?P<message>.*)$'
            - labels:
                level:
            - timestamp:
                source: timestamp
                format: '2006-01-02 15:04:05'
EOF
```

---

## 🎨 Passo 3: Configuração Avançada do Grafana

### 3.1 Configuração de Data Sources

```bash
# Criar configuração de datasource
mkdir -p ~/loki-stack/config/grafana/provisioning/{datasources,dashboards}

cat > ~/loki-stack/config/grafana/provisioning/datasources/loki.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    editable: true
    jsonData:
      maxLines: 1000
      derivedFields:
        - datasourceUid: prometheus
          matcherRegex: "traceID=(\\w+)"
          name: TraceID
          url: "$${__value.raw}"
        - datasourceUid: prometheus
          matcherRegex: "user_id=(\\w+)"
          name: UserID
          url: "/explore?left=[\"now-1h\",\"now\",\"Loki\",{\"expr\":\"{user_id=\\\"$${__value.raw}\\\"}\"}]"

  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    uid: prometheus
    editable: true
    isDefault: false
EOF
```

### 3.2 Dashboard de Logs Avançado

```bash
cat > ~/loki-stack/config/grafana/provisioning/dashboards/logs-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Loki Logs - Advanced Dashboard",
    "tags": ["loki", "logs", "monitoring"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Log Volume by Job",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (job) (rate({job=~\".+\"}[5m]))",
            "refId": "A",
            "legendFormat": "{{job}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "palette-classic"},
            "custom": {"displayMode": "list", "orientation": "horizontal"},
            "mappings": [],
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 100},
                {"color": "red", "value": 1000}
              ]
            },
            "unit": "logs/sec"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate({level=\"error\"}[5m]))",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {"mode": "thresholds"},
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 10}
              ]
            },
            "unit": "errors/sec"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Recent Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=~\".+\"}",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "showCommonLabels": false,
          "wrapLogMessage": true,
          "prettifyLogMessage": false,
          "enableLogDetails": true,
          "dedupStrategy": "none",
          "sortOrder": "Descending"
        },
        "gridPos": {"h": 12, "w": 24, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Log Levels Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (level) (count_over_time({level=~\".+\"}[1h]))",
            "refId": "A",
            "legendFormat": "{{level}}"
          }
        ],
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"],
            "fields": ""
          },
          "pieType": "pie",
          "tooltip": {"mode": "single"},
          "legend": {
            "displayMode": "visible",
            "placement": "right"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20}
      },
      {
        "id": 5,
        "title": "Top Services by Log Volume",
        "type": "barchart",
        "targets": [
          {
            "expr": "topk(10, sum by (service) (count_over_time({service=~\".+\"}[1h])))",
            "refId": "A",
            "legendFormat": "{{service}}"
          }
        ],
        "options": {
          "orientation": "horizontal",
          "barWidth": 0.97,
          "groupWidth": 0.7,
          "legend": {"displayMode": "hidden"}
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s",
    "schemaVersion": 27,
    "version": 1
  }
}
EOF
```

### 3.3 Configuração de Dashboards

```bash
cat > ~/loki-stack/config/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
```

---

## 🔔 Passo 4: Configuração de Alertas

### 4.1 Criar Regras de Alerta

```bash
mkdir -p ~/loki-stack/config/loki/rules

cat > ~/loki-stack/config/loki/rules/alerts.yml << 'EOF'
groups:
  - name: loki_alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate({level="error"}[5m])) > 10
        for: 2m
        labels:
          severity: warning
          service: loki
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"

      - alert: LogVolumeHigh
        expr: |
          sum(rate({job=~".+"}[5m])) > 1000
        for: 5m
        labels:
          severity: warning
          service: loki
        annotations:
          summary: "High log volume detected"
          description: "Log ingestion rate is {{ $value }} logs per second"

      - alert: LokiDown
        expr: |
          up{job="loki"} == 0
        for: 1m
        labels:
          severity: critical
          service: loki
        annotations:
          summary: "Loki is down"
          description: "Loki has been down for more than 1 minute"

      - alert: PromtailDown
        expr: |
          up{job="promtail"} == 0
        for: 1m
        labels:
          severity: critical
          service: promtail
        annotations:
          summary: "Promtail is down"
          description: "Promtail has been down for more than 1 minute"

      - alert: DiskSpaceHigh
        expr: |
          (
            sum(loki_ingester_chunks_stored_total) * 1024 * 1024
          ) > (0.8 * 10 * 1024 * 1024 * 1024)
        for: 5m
        labels:
          severity: warning
          service: loki
        annotations:
          summary: "Loki disk usage high"
          description: "Loki is using more than 80% of allocated disk space"
EOF
```

---

## 🔄 Passo 5: Atualizar Docker Compose

### 5.1 Docker Compose Avançado

```bash
cat > ~/loki-stack/docker-compose.yml << 'EOF'
version: "3.8"

networks:
  loki:
    driver: bridge

volumes:
  grafana-data:
  loki-data:

services:
  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./config/loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - ./config/loki/rules:/loki/rules:ro
      - loki-data:/loki
    networks:
      - loki
    environment:
      - HOSTNAME=${HOSTNAME:-localhost}
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./config/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./logs:/logs:ro
      - /etc/hostname:/etc/hostname:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - loki
    environment:
      - HOSTNAME=${HOSTNAME:-localhost}
    depends_on:
      loki:
        condition: service_healthy
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SECURITY_ALLOW_EMBEDDING=true
      - GF_AUTH_ANONYMOUS_ENABLED=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - loki
    depends_on:
      loki:
        condition: service_healthy
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Opcional: Prometheus para métricas
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
    volumes:
      - ./config/prometheus:/etc/prometheus:ro
      - prometheus-data:/prometheus
    networks:
      - loki
    profiles:
      - monitoring

volumes:
  prometheus-data:
EOF
```

### 5.2 Configuração do Prometheus (Opcional)

```bash
mkdir -p ~/loki-stack/config/prometheus

cat > ~/loki-stack/config/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'promtail'
    static_configs:
      - targets: ['promtail:9080']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
EOF
```

---

## 🚀 Passo 6: Aplicar Configurações

### 6.1 Reiniciar Serviços

```bash
cd ~/loki-stack

# Parar serviços
docker-compose down

# Iniciar com nova configuração
docker-compose up -d

# Verificar status
docker-compose ps
docker-compose logs -f
```

### 6.2 Verificar Configurações

```bash
# Testar API do Loki
curl -s http://localhost:3100/ready

# Verificar regras de alerta
curl -s http://localhost:3100/loki/api/v1/rules

# Testar Grafana
curl -s http://localhost:3000/api/health

# Verificar métricas do Promtail
curl -s http://localhost:9080/metrics | grep promtail
```

---

## 📊 Passo 7: Configuração de Monitoramento

### 7.1 Script de Monitoramento

```bash
cat > ~/loki-stack/monitor.sh << 'EOF'
#!/bin/bash

echo "=== Loki Stack Status ==="
echo "Date: $(date)"
echo

echo "=== Container Status ==="
docker-compose ps
echo

echo "=== Disk Usage ==="
df -h ~/loki-stack/data/
echo

echo "=== Loki Health ==="
curl -s http://localhost:3100/ready && echo "✅ Loki OK" || echo "❌ Loki DOWN"
echo

echo "=== Grafana Health ==="
curl -s http://localhost:3000/api/health | jq -r '.database' 2>/dev/null && echo "✅ Grafana OK" || echo "❌ Grafana DOWN"
echo

echo "=== Log Ingestion Rate ==="
curl -s "http://localhost:3100/loki/api/v1/query?query=sum(rate({job=~\".%2B\"}[1m]))" | jq -r '.data.result[0].value[1]' 2>/dev/null | xargs -I {} echo "Current rate: {} logs/sec"
echo

echo "=== Recent Errors ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={level=\"error\"}&limit=5" | jq -r '.data.result[].values[][]' 2>/dev/null | tail -5
EOF

chmod +x ~/loki-stack/monitor.sh
```

### 7.2 Cron Job para Monitoramento

```bash
# Adicionar ao crontab para executar a cada 5 minutos
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/loki-stack/monitor.sh >> ~/loki-stack/logs/monitor.log 2>&1") | crontab -
```

---

## ✅ Verificação Final

### Checklist de Configuração

- [ ] Loki respondendo na porta 3100
- [ ] Promtail coletando logs
- [ ] Grafana acessível na porta 3000
- [ ] Data source Loki configurado no Grafana
- [ ] Dashboard de logs funcionando
- [ ] Regras de alerta configuradas
- [ ] Monitoramento automatizado ativo

### Comandos de Teste

```bash
# Teste completo
cd ~/loki-stack
./monitor.sh

# Gerar logs de teste
echo "$(date) INFO Test log message" >> logs/test.log
echo "$(date) ERROR Test error message" >> logs/test.log

# Verificar se logs aparecem no Grafana
# Acesse: http://localhost:3000/explore
```

---

## 🎯 Próximos Passos

1. [[Docker-Logs/03-Docker-Logs|Configurar Logs do Docker]]
2. [[Server-Logs/04-Server-Logs|Configurar Logs do Servidor]]
3. [[Security/05-Seguranca-Autenticacao|Implementar Segurança]]

---

*✅ Configuração avançada concluída! Seu sistema de logs está otimizado e monitorado.*

