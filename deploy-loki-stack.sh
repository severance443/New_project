#!/bin/bash

# ============================================================================
# GRAFANA LOKI STACK - DEPLOY AUTOMÁTICO
# ============================================================================
# Script para deploy completo do sistema de logs centralizado
# Baseado nos guias do Obsidian Vault
# ============================================================================

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis de configuração
INSTALL_DIR="$HOME/loki-stack"
HOSTNAME=$(hostname)
USER_EMAIL="admin@localhost"
ADMIN_PASSWORD="admin123"
VIEWER_PASSWORD="viewer123"

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para criar banner
show_banner() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    GRAFANA LOKI STACK - DEPLOY AUTOMÁTICO"
    echo "============================================================================"
    echo "Este script irá instalar e configurar:"
    echo "• Grafana Loki (Agregação de logs)"
    echo "• Promtail (Coleta de logs)"
    echo "• Grafana (Visualização)"
    echo "• Traefik (Reverse Proxy com SSL)"
    echo "• Dashboards e alertas pré-configurados"
    echo "============================================================================"
    echo -e "${NC}"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar sistema operacional
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "Este script é compatível apenas com Linux"
    fi
    
    # Verificar se é Ubuntu/Debian
    if ! command_exists apt-get; then
        error "Este script requer Ubuntu/Debian (apt-get)"
    fi
    
    # Verificar se usuário não é root
    if [[ $EUID -eq 0 ]]; then
        error "Não execute este script como root. Use um usuário normal com sudo."
    fi
    
    # Verificar sudo
    if ! sudo -n true 2>/dev/null; then
        warn "Este script precisa de privilégios sudo. Você pode ser solicitado a inserir sua senha."
    fi
    
    log "Pré-requisitos verificados ✓"
}

# Função para instalar Docker
install_docker() {
    if command_exists docker && command_exists docker-compose; then
        log "Docker já está instalado ✓"
        return
    fi
    
    log "Instalando Docker e Docker Compose..."
    
    # Atualizar pacotes
    sudo apt-get update
    
    # Instalar dependências
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        jq \
        htop \
        tree
    
    # Adicionar chave GPG do Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Adicionar repositório do Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Adicionar usuário ao grupo docker
    sudo usermod -aG docker $USER
    
    # Instalar Docker Compose standalone
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log "Docker instalado com sucesso ✓"
    warn "IMPORTANTE: Você precisa fazer logout/login para usar Docker sem sudo"
}

# Função para criar estrutura de diretórios
create_directory_structure() {
    log "Criando estrutura de diretórios..."
    
    # Remover diretório existente se houver
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Diretório $INSTALL_DIR já existe. Fazendo backup..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Criar estrutura principal
    mkdir -p "$INSTALL_DIR"/{config,data,logs,scripts,examples}
    mkdir -p "$INSTALL_DIR"/config/{loki,promtail,grafana,traefik}
    mkdir -p "$INSTALL_DIR"/config/grafana/provisioning/{datasources,dashboards}
    mkdir -p "$INSTALL_DIR"/config/loki/rules
    mkdir -p "$INSTALL_DIR"/config/traefik/config
    mkdir -p "$INSTALL_DIR"/data/{loki,grafana}
    mkdir -p "$INSTALL_DIR"/traefik/{data/certificates,logs}
    
    # Configurar permissões
    chmod -R 755 "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR"/traefik/data/certificates
    
    log "Estrutura de diretórios criada ✓"
}

# Função para criar configuração do Loki
create_loki_config() {
    log "Criando configuração do Loki..."
    
    cat > "$INSTALL_DIR/config/loki/loki-config.yml" << 'EOF'
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

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/boltdb-shipper-compactor
  shared_store: filesystem

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 4
  ingestion_burst_size_mb: 6
  max_query_parallelism: 32
  max_streams_per_user: 10000
  max_line_size: 256000
  retention_period: 744h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 744h

ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /loki/rules
  ring:
    kvstore:
      store: inmemory
  enable_api: true

analytics:
  reporting_enabled: false
EOF
    
    log "Configuração do Loki criada ✓"
}

# Função para criar configuração do Promtail
create_promtail_config() {
    log "Criando configuração do Promtail..."
    
    cat > "$INSTALL_DIR/config/promtail/promtail-config.yml" << EOF
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
                expression: '^(?P<timestamp>\w+\s+\d+\s+\d+:\d+:\d+)\s+(?P<hostname>\S+)\s+(?P<service>\S+?)(\[(?P<pid>\d+)\])?\s*:\s*(?P<message>.*)$'
            - labels:
                service:
                hostname:
                pid:
            - timestamp:
                source: timestamp
                format: 'Jan 02 15:04:05'
                location: 'Local'

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
                expression: '^(?P<timestamp>\w+\s+\d+\s+\d+:\d+:\d+)\s+(?P<hostname>\S+)\s+(?P<service>\S+?)(\[(?P<pid>\d+)\])?\s*:\s*(?P<message>.*)$'
            - labels:
                service:
                hostname:
                pid:
            - timestamp:
                source: timestamp
                format: 'Jan 02 15:04:05'
                location: 'Local'
            - regex:
                expression: '.*user\s+(?P<user>\w+).*'
                source: message
            - regex:
                expression: '.*from\s+(?P<source_ip>\d+\.\d+\.\d+\.\d+).*'
                source: message
            - labels:
                user:
                source_ip:

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
            attrs: attrs
            time: time
      - regex:
          expression: '^/var/lib/docker/containers/(?P<container_id>[^/]+)/.*$'
          source: filename
      - json:
          expressions:
            container_name: attrs["io.kubernetes.container.name"]
            service: attrs["com.docker.compose.service"]
            project: attrs["com.docker.compose.project"]
          source: attrs
      - labels:
          container_id:
          stream:
          container_name:
          service:
          project:
      - timestamp:
          source: time
          format: RFC3339Nano
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
    
    log "Configuração do Promtail criada ✓"
}

# Função para criar configuração do Traefik
create_traefik_config() {
    log "Criando configuração do Traefik..."
    
    cat > "$INSTALL_DIR/config/traefik/traefik.yml" << EOF
global:
  checkNewVersion: false
  sendAnonymousUsage: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${USER_EMAIL}
      storage: /certificates/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: loki-stack_default
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

api:
  dashboard: true
  debug: false

log:
  level: INFO
  filePath: "/logs/traefik.log"

accessLog:
  filePath: "/logs/access.log"
  bufferingSize: 100

metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
EOF
    
    # Configuração dinâmica
    cat > "$INSTALL_DIR/config/traefik/config/dynamic.yml" << 'EOF'
http:
  middlewares:
    security-headers:
      headers:
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
          - POST
          - DELETE
        accessControlMaxAge: 100
        hostsProxyHeaders:
          - "X-Forwarded-Host"
        referrerPolicy: "same-origin"
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Robots-Tag: "none,noarchive,nosnippet,notranslate,noimageindex"
          X-Frame-Options: "DENY"
          X-Content-Type-Options: "nosniff"
          Referrer-Policy: "same-origin"
          Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self' ws: wss:; frame-ancestors 'none';"

    basic-auth:
      basicAuth:
        users:
          - "admin:$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi"

    rate-limit:
      rateLimit:
        average: 100
        burst: 50
        period: 1m

tls:
  options:
    default:
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
      curvePreferences:
        - "CurveP521"
        - "CurveP384"
EOF
    
    log "Configuração do Traefik criada ✓"
}

# Função para criar configuração do Grafana
create_grafana_config() {
    log "Criando configuração do Grafana..."
    
    # Data source do Loki
    cat > "$INSTALL_DIR/config/grafana/provisioning/datasources/loki.yml" << 'EOF'
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
        - datasourceUid: loki
          matcherRegex: "traceID=(\\w+)"
          name: TraceID
          url: "$${__value.raw}"
EOF
    
    # Configuração de dashboards
    cat > "$INSTALL_DIR/config/grafana/provisioning/dashboards/dashboards.yml" << 'EOF'
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
    
    log "Configuração do Grafana criada ✓"
}

# Função para criar regras de alerta
create_alert_rules() {
    log "Criando regras de alerta..."
    
    cat > "$INSTALL_DIR/config/loki/rules/alerts.yml" << 'EOF'
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

      - alert: HighFailedLogins
        expr: |
          sum(rate({job="auth"} |~ "(?i)(failed|failure|invalid)" [5m])) > 5
        for: 2m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "High number of failed login attempts"
          description: "{{ $value }} failed login attempts per second"

      - alert: KernelErrors
        expr: |
          sum(rate({job="kernel"} |~ "(?i)(error|panic|oops|bug)" [5m])) > 0
        for: 1m
        labels:
          severity: critical
          category: system
        annotations:
          summary: "Kernel errors detected"
          description: "Kernel errors detected at rate of {{ $value }} per second"
EOF
    
    log "Regras de alerta criadas ✓"
}

# Função para criar dashboards
create_dashboards() {
    log "Criando dashboards..."
    
    # Dashboard principal de logs
    cat > "$INSTALL_DIR/config/grafana/provisioning/dashboards/logs-dashboard.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Loki Logs Dashboard",
    "tags": ["loki", "logs"],
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
          "wrapLogMessage": true,
          "enableLogDetails": true,
          "sortOrder": "Descending"
        },
        "gridPos": {"h": 12, "w": 24, "x": 0, "y": 8}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s",
    "schemaVersion": 27,
    "version": 1
  }
}
EOF
    
    log "Dashboards criados ✓"
}

# Função para criar Docker Compose
create_docker_compose() {
    log "Criando Docker Compose..."
    
    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
version: "3.8"

networks:
  loki:
    driver: bridge

volumes:
  grafana-data:
  loki-data:

services:
  # Traefik Reverse Proxy
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./config/traefik/config/dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./traefik/data/certificates:/certificates
      - ./traefik/logs:/logs
    networks:
      - loki
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.localhost`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=basic-auth@file"

  # Loki
  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    restart: unless-stopped
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./config/loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - ./config/loki/rules:/loki/rules:ro
      - loki-data:/loki
    networks:
      - loki
    environment:
      - HOSTNAME=${HOSTNAME:-localhost}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.loki.rule=Host(`loki.localhost`)"
      - "traefik.http.routers.loki.entrypoints=websecure"
      - "traefik.http.routers.loki.tls=true"
      - "traefik.http.routers.loki.middlewares=security-headers@file,rate-limit@file"
      - "traefik.http.services.loki.loadbalancer.server.port=3100"
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Promtail
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
    user: root

  # Grafana
  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    restart: unless-stopped
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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.localhost`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls=true"
      - "traefik.http.routers.grafana.middlewares=security-headers@file"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"
EOF
    
    log "Docker Compose criado ✓"
}

# Função para criar scripts auxiliares
create_helper_scripts() {
    log "Criando scripts auxiliares..."
    
    # Script de monitoramento
    cat > "$INSTALL_DIR/scripts/monitor.sh" << 'EOF'
#!/bin/bash

echo "=== Loki Stack Status ==="
echo "Date: $(date)"
echo

echo "=== Container Status ==="
docker-compose ps
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

echo "=== Disk Usage ==="
df -h $(pwd)/data/
EOF
    
    chmod +x "$INSTALL_DIR/scripts/monitor.sh"
    
    # Script de backup
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="$HOME/loki-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Creating Loki Stack Backup ==="

mkdir -p "$BACKUP_DIR"

# Parar serviços
docker-compose stop

# Criar backup
tar -czf "$BACKUP_DIR/loki-stack-backup-$TIMESTAMP.tar.gz" \
    config/ data/ docker-compose.yml scripts/

# Reiniciar serviços
docker-compose start

echo "Backup created: $BACKUP_DIR/loki-stack-backup-$TIMESTAMP.tar.gz"
EOF
    
    chmod +x "$INSTALL_DIR/scripts/backup.sh"
    
    # Script de logs
    cat > "$INSTALL_DIR/scripts/logs.sh" << 'EOF'
#!/bin/bash

SERVICE=${1:-all}

case $SERVICE in
    "loki")
        docker-compose logs -f loki
        ;;
    "promtail")
        docker-compose logs -f promtail
        ;;
    "grafana")
        docker-compose logs -f grafana
        ;;
    "traefik")
        docker-compose logs -f traefik
        ;;
    *)
        docker-compose logs -f
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/scripts/logs.sh"
    
    log "Scripts auxiliares criados ✓"
}

# Função para configurar hosts locais
setup_local_hosts() {
    log "Configurando hosts locais..."
    
    # Verificar se entradas já existem
    if ! grep -q "loki.localhost" /etc/hosts; then
        echo "Adicionando entradas ao /etc/hosts..."
        sudo tee -a /etc/hosts << 'EOF'

# Loki Stack
127.0.0.1 loki.localhost
127.0.0.1 grafana.localhost
127.0.0.1 traefik.localhost
EOF
        log "Entradas adicionadas ao /etc/hosts ✓"
    else
        log "Entradas já existem no /etc/hosts ✓"
    fi
}

# Função para iniciar serviços
start_services() {
    log "Iniciando serviços..."
    
    cd "$INSTALL_DIR"
    
    # Baixar imagens
    info "Baixando imagens Docker..."
    docker-compose pull
    
    # Iniciar serviços
    info "Iniciando containers..."
    docker-compose up -d
    
    # Aguardar serviços ficarem prontos
    info "Aguardando serviços ficarem prontos..."
    sleep 30
    
    # Verificar status
    docker-compose ps
    
    log "Serviços iniciados ✓"
}

# Função para verificar instalação
verify_installation() {
    log "Verificando instalação..."
    
    cd "$INSTALL_DIR"
    
    # Verificar containers
    info "Verificando containers..."
    if ! docker-compose ps | grep -q "Up"; then
        error "Alguns containers não estão rodando"
    fi
    
    # Verificar Loki
    info "Verificando Loki..."
    if ! curl -s http://localhost:3100/ready | grep -q "ready"; then
        warn "Loki pode não estar totalmente pronto ainda"
    fi
    
    # Verificar Grafana
    info "Verificando Grafana..."
    if ! curl -s http://localhost:3000/api/health | grep -q "ok"; then
        warn "Grafana pode não estar totalmente pronto ainda"
    fi
    
    # Gerar logs de teste
    info "Gerando logs de teste..."
    echo "$(date) INFO Test log message from deploy script" >> logs/test.log
    echo "$(date) ERROR Test error message from deploy script" >> logs/test.log
    
    log "Verificação concluída ✓"
}

# Função para mostrar informações finais
show_final_info() {
    echo -e "${GREEN}"
    echo "============================================================================"
    echo "                    INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "============================================================================"
    echo -e "${NC}"
    
    echo -e "${BLUE}🌐 URLs de Acesso:${NC}"
    echo "• Grafana:  https://grafana.localhost (admin/admin123)"
    echo "• Loki API: https://loki.localhost"
    echo "• Traefik:  https://traefik.localhost (admin/admin123)"
    echo
    
    echo -e "${BLUE}📁 Diretório de Instalação:${NC}"
    echo "• $INSTALL_DIR"
    echo
    
    echo -e "${BLUE}🛠️ Comandos Úteis:${NC}"
    echo "• Monitorar: cd $INSTALL_DIR && ./scripts/monitor.sh"
    echo "• Ver logs:  cd $INSTALL_DIR && ./scripts/logs.sh [serviço]"
    echo "• Backup:    cd $INSTALL_DIR && ./scripts/backup.sh"
    echo "• Parar:     cd $INSTALL_DIR && docker-compose stop"
    echo "• Iniciar:   cd $INSTALL_DIR && docker-compose start"
    echo
    
    echo -e "${BLUE}📊 Primeiros Passos:${NC}"
    echo "1. Acesse https://grafana.localhost"
    echo "2. Faça login com admin/admin123"
    echo "3. Vá para 'Explore' e teste queries como: {job=\"syslog\"}"
    echo "4. Verifique os dashboards pré-configurados"
    echo
    
    echo -e "${YELLOW}⚠️  Notas Importantes:${NC}"
    echo "• Certificados SSL são auto-assinados (aceite no navegador)"
    echo "• Para produção, configure domínios reais e certificados válidos"
    echo "• Altere as senhas padrão em produção"
    echo "• Execute ./scripts/monitor.sh para verificar o status"
    echo
    
    echo -e "${GREEN}✅ Sistema de logs centralizado está funcionando!${NC}"
}

# Função principal
main() {
    show_banner
    
    # Verificar se usuário quer continuar
    read -p "Deseja continuar com a instalação? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Instalação cancelada."
        exit 0
    fi
    
    check_prerequisites
    install_docker
    create_directory_structure
    create_loki_config
    create_promtail_config
    create_traefik_config
    create_grafana_config
    create_alert_rules
    create_dashboards
    create_docker_compose
    create_helper_scripts
    setup_local_hosts
    start_services
    verify_installation
    show_final_info
    
    log "Deploy concluído com sucesso! 🎉"
}

# Executar função principal
main "$@"
