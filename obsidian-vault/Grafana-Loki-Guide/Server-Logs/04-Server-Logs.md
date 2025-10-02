# 🖥️ Configuração de Logs do Servidor Linux para Loki

> **Tempo estimado:** 25-35 minutos  
> **Dificuldade:** Intermediário  
> **Pré-requisitos:** Loki e Promtail instalados

## 📋 Visão Geral

Neste guia, você aprenderá a configurar o Promtail para coletar logs do sistema Linux, incluindo:

- **Logs do sistema (syslog, auth.log, kern.log)**
- **Logs de aplicações específicas**
- **Logs do systemd/journald**
- **Configuração de parsing e filtragem**
- **Monitoramento de arquivos de log personalizados**

---

## 📂 Passo 1: Identificação dos Logs do Sistema

### 1.1 Localizar Arquivos de Log

```bash
# Verificar estrutura de logs do sistema
ls -la /var/log/

# Logs principais do sistema
echo "=== Principais arquivos de log ==="
ls -lh /var/log/{syslog,auth.log,kern.log,daemon.log,user.log,mail.log} 2>/dev/null

# Verificar logs do systemd
echo "=== Logs do systemd ==="
journalctl --disk-usage
journalctl --list-boots | head -5

# Verificar rotação de logs
echo "=== Configuração de rotação ==="
ls -la /etc/logrotate.d/ | head -10
```

### 1.2 Verificar Permissões

```bash
# Verificar permissões dos arquivos de log
echo "=== Permissões dos logs ==="
ls -la /var/log/ | grep -E "(syslog|auth|kern|daemon)"

# Verificar grupos
echo "=== Grupos do usuário atual ==="
groups $USER

# Adicionar usuário ao grupo adm/syslog se necessário
sudo usermod -a -G adm $USER
sudo usermod -a -G syslog $USER

# Verificar se Docker pode acessar logs
docker run --rm -v /var/log:/var/log:ro alpine ls -la /var/log/
```

---

## ⚙️ Passo 2: Configuração Avançada do Promtail

### 2.1 Configuração Completa para Logs do Sistema

```bash
# Backup da configuração atual
cp ~/loki-stack/config/promtail/promtail-config.yml ~/loki-stack/config/promtail/promtail-config-server.yml.backup

# Nova configuração otimizada para servidor Linux
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
  # ========== LOGS DO SISTEMA ==========
  
  # Syslog principal
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
            # Extrair informações específicas de auth
            - regex:
                expression: '.*user\s+(?P<user>\w+).*'
                source: message
            - regex:
                expression: '.*from\s+(?P<source_ip>\d+\.\d+\.\d+\.\d+).*'
                source: message
            - labels:
                user:
                source_ip:

  # Logs do kernel
  - job_name: kernel
    static_configs:
      - targets:
          - localhost
        labels:
          job: kernel
          host: ${HOSTNAME}
          __path__: /var/log/kern.log
    pipeline_stages:
      - match:
          selector: '{job="kernel"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\w+\s+\d+\s+\d+:\d+:\d+)\s+(?P<hostname>\S+)\s+kernel:\s*\[(?P<kernel_time>\s*\d+\.\d+)\]\s*(?P<message>.*)$'
            - labels:
                hostname:
                kernel_time:
            - timestamp:
                source: timestamp
                format: 'Jan 02 15:04:05'
                location: 'Local'

  # Logs de daemon
  - job_name: daemon
    static_configs:
      - targets:
          - localhost
        labels:
          job: daemon
          host: ${HOSTNAME}
          __path__: /var/log/daemon.log
    pipeline_stages:
      - match:
          selector: '{job="daemon"}'
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

  # ========== LOGS DE APLICAÇÕES ==========

  # Nginx logs
  - job_name: nginx-access
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-access
          host: ${HOSTNAME}
          __path__: /var/log/nginx/access.log
    pipeline_stages:
      - match:
          selector: '{job="nginx-access"}'
          stages:
            - regex:
                expression: '^(?P<remote_addr>\S+) - (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<request>\S+) (?P<protocol>\S+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'
            - labels:
                method:
                status:
                remote_addr:
            - timestamp:
                source: time_local
                format: '02/Jan/2006:15:04:05 -0700'

  - job_name: nginx-error
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-error
          host: ${HOSTNAME}
          __path__: /var/log/nginx/error.log
    pipeline_stages:
      - match:
          selector: '{job="nginx-error"}'
          stages:
            - regex:
                expression: '^(?P<timestamp>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?P<level>\w+)\] (?P<pid>\d+)#(?P<tid>\d+): (?P<message>.*?)(?:, client: (?P<client>\S+))?(?:, server: (?P<server>\S+))?(?:, request: "(?P<request>[^"]*)")?(?:, host: "(?P<host>[^"]*)")?'
            - labels:
                level:
                pid:
                client:
                server:
            - timestamp:
                source: timestamp
                format: '2006/01/02 15:04:05'

  # Apache logs
  - job_name: apache-access
    static_configs:
      - targets:
          - localhost
        labels:
          job: apache-access
          host: ${HOSTNAME}
          __path__: /var/log/apache2/access.log
    pipeline_stages:
      - match:
          selector: '{job="apache-access"}'
          stages:
            - regex:
                expression: '^(?P<remote_addr>\S+) (?P<remote_logname>\S+) (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<request>\S+) (?P<protocol>\S+)" (?P<status>\d+) (?P<bytes_sent>\S+)'
            - labels:
                method:
                status:
                remote_addr:
            - timestamp:
                source: time_local
                format: '02/Jan/2006:15:04:05 -0700'

  - job_name: apache-error
    static_configs:
      - targets:
          - localhost
        labels:
          job: apache-error
          host: ${HOSTNAME}
          __path__: /var/log/apache2/error.log
    pipeline_stages:
      - match:
          selector: '{job="apache-error"}'
          stages:
            - regex:
                expression: '^\[(?P<timestamp>[^\]]+)\] \[(?P<level>\w+)\] (?P<message>.*)'
            - labels:
                level:
            - timestamp:
                source: timestamp
                format: 'Mon Jan 02 15:04:05.000000 2006'

  # ========== LOGS DO DOCKER ==========

  - job_name: docker-containers
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

  # ========== LOGS PERSONALIZADOS ==========

  # Logs de aplicações personalizadas
  - job_name: custom-apps
    static_configs:
      - targets:
          - localhost
        labels:
          job: custom-apps
          host: ${HOSTNAME}
          __path__: /logs/*.log
    pipeline_stages:
      - match:
          selector: '{job="custom-apps"}'
          stages:
            - multiline:
                firstline: '^\d{4}-\d{2}-\d{2}'
                max_wait_time: 3s
            - regex:
                expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(?P<level>\w+)\s+(?P<logger>\S+)\s+(?P<message>.*)$'
            - labels:
                level:
                logger:
            - timestamp:
                source: timestamp
                format: '2006-01-02 15:04:05'

  # ========== LOGS DO SYSTEMD/JOURNALD ==========

  - job_name: systemd-journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        host: ${HOSTNAME}
    pipeline_stages:
      - json:
          expressions:
            message: MESSAGE
            unit: _SYSTEMD_UNIT
            priority: PRIORITY
            hostname: _HOSTNAME
            pid: _PID
      - labels:
          unit:
          priority:
          hostname:
          pid:
      - match:
          selector: '{job="systemd-journal"}'
          stages:
            - drop:
                expression: '^$'
                source: message
      - output:
          source: message
EOF
```

---

## 🔧 Passo 3: Configuração do Systemd Journal

### 3.1 Configurar Acesso ao Journal

```bash
# Verificar se usuário pode acessar journal
sudo usermod -a -G systemd-journal $USER

# Verificar configuração do journal
sudo cat /etc/systemd/journald.conf

# Configurar journal para persistência (se necessário)
sudo tee -a /etc/systemd/journald.conf << 'EOF'

# Configurações para Loki
Storage=persistent
Compress=yes
MaxRetentionSec=7day
MaxFileSec=1day
EOF

# Reiniciar journald
sudo systemctl restart systemd-journald
```

### 3.2 Testar Acesso ao Journal

```bash
# Testar acesso básico
journalctl --no-pager -n 10

# Testar filtros
journalctl --no-pager -u docker -n 5
journalctl --no-pager -p err -n 5

# Verificar se Promtail pode acessar
docker run --rm -v /run/systemd/journal:/run/systemd/journal:ro \
  -v /var/log/journal:/var/log/journal:ro \
  grafana/promtail:2.9.0 \
  journalctl --no-pager -n 5
```

---

## 📊 Passo 4: Dashboard para Logs do Servidor

### 4.1 Dashboard de Sistema Linux

```bash
cat > ~/loki-stack/config/grafana/provisioning/dashboards/linux-system-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Linux System Logs",
    "tags": ["linux", "system", "logs"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Log Volume by Service",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (job) (rate({job=~\"(syslog|auth|kernel|daemon)\"}[5m]))",
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
        "title": "Authentication Events",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate({job=\"auth\"}[5m]))",
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
            "unit": "events/sec"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Recent System Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=~\"(syslog|auth|kernel|daemon)\"}",
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
      },
      {
        "id": 4,
        "title": "Failed Login Attempts",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"auth\"} |~ \"(?i)(failed|failure|invalid)\"",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "wrapLogMessage": true,
          "enableLogDetails": true
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 20}
      },
      {
        "id": 5,
        "title": "Kernel Messages",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"kernel\"}",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "wrapLogMessage": true,
          "enableLogDetails": true
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 20}
      },
      {
        "id": 6,
        "title": "Top Services by Log Volume",
        "type": "barchart",
        "targets": [
          {
            "expr": "topk(10, sum by (service) (count_over_time({service!=\"\"}[1h])))",
            "refId": "A",
            "legendFormat": "{{service}}"
          }
        ],
        "options": {
          "orientation": "horizontal",
          "legend": {"displayMode": "hidden"}
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 28}
      },
      {
        "id": 7,
        "title": "Authentication Sources",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (source_ip) (count_over_time({job=\"auth\", source_ip!=\"\"}[1h]))",
            "refId": "A",
            "legendFormat": "{{source_ip}}"
          }
        ],
        "options": {
          "legend": {"displayMode": "visible", "placement": "right"}
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 28}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s"
  }
}
EOF
```

---

## 🔔 Passo 5: Alertas para Logs do Sistema

### 5.1 Regras de Alerta do Sistema

```bash
cat > ~/loki-stack/config/loki/rules/system-alerts.yml << 'EOF'
groups:
  - name: system_alerts
    rules:
      - alert: HighFailedLogins
        expr: |
          sum(rate({job="auth"} |~ "(?i)(failed|failure|invalid)" [5m])) > 5
        for: 2m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "High number of failed login attempts"
          description: "{{ $value }} failed login attempts per second in the last 5 minutes"

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

      - alert: SystemdServiceFailed
        expr: |
          sum(rate({job="systemd-journal"} |~ "(?i)(failed|error)" [5m])) > 2
        for: 2m
        labels:
          severity: warning
          category: system
        annotations:
          summary: "Systemd service failures detected"
          description: "{{ $value }} systemd service failures per second"

      - alert: DiskSpaceWarning
        expr: |
          sum(rate({job="syslog"} |~ "(?i)(no space|disk full|filesystem full)" [5m])) > 0
        for: 1m
        labels:
          severity: critical
          category: storage
        annotations:
          summary: "Disk space issues detected"
          description: "Disk space warnings found in system logs"

      - alert: HighSystemLogVolume
        expr: |
          sum(rate({job=~"(syslog|auth|kernel|daemon)"}[5m])) > 50
        for: 5m
        labels:
          severity: warning
          category: system
        annotations:
          summary: "High system log volume"
          description: "System generating {{ $value }} logs per second"

      - alert: SuspiciousActivity
        expr: |
          sum(rate({job="auth"} |~ "(?i)(sudo|su |root)" [5m])) > 10
        for: 3m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "High privilege escalation activity"
          description: "{{ $value }} privilege escalation attempts per second"

      - alert: NetworkErrors
        expr: |
          sum(rate({job="kernel"} |~ "(?i)(network|eth0|connection)" |~ "(?i)(error|fail|timeout)" [5m])) > 1
        for: 2m
        labels:
          severity: warning
          category: network
        annotations:
          summary: "Network errors detected"
          description: "Network-related errors at {{ $value }} per second"
EOF
```

---

## 🔄 Passo 6: Aplicar Configurações

### 6.1 Atualizar Docker Compose para Logs do Sistema

```bash
# Atualizar docker-compose para incluir acesso aos logs do sistema
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

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./config/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      # Logs do sistema
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      # Logs personalizados
      - ./logs:/logs:ro
      # Systemd journal
      - /run/systemd/journal:/run/systemd/journal:ro
      - /var/log/journal:/var/log/journal:ro
      # Hostname
      - /etc/hostname:/etc/hostname:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - loki
    environment:
      - HOSTNAME=${HOSTNAME:-localhost}
    depends_on:
      loki:
        condition: service_healthy
    # Executar como root para acessar logs do sistema
    user: root

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
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - loki
    depends_on:
      loki:
        condition: service_healthy
EOF
```

### 6.2 Reiniciar Serviços

```bash
cd ~/loki-stack

# Parar serviços
docker-compose down

# Iniciar com nova configuração
docker-compose up -d

# Verificar logs do Promtail
docker-compose logs -f promtail
```

---

## 📈 Passo 7: Scripts de Monitoramento

### 7.1 Script de Monitoramento do Sistema

```bash
cat > ~/loki-stack/scripts/monitor-system-logs.sh << 'EOF'
#!/bin/bash

echo "=== Linux System Logs Monitoring ==="
echo "Date: $(date)"
echo

echo "=== System Log Files Status ==="
for log_file in /var/log/{syslog,auth.log,kern.log,daemon.log}; do
    if [ -f "$log_file" ]; then
        size=$(du -h "$log_file" | cut -f1)
        lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
        echo "$log_file: $size ($lines lines)"
    else
        echo "$log_file: Not found"
    fi
done
echo

echo "=== Recent Failed Logins ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"auth\"} |~ \"(?i)(failed|failure|invalid)\"&limit=5" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -3
echo

echo "=== Recent Kernel Messages ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"kernel\"}&limit=3" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -3
echo

echo "=== System Log Ingestion Rate ==="
syslog_rate=$(curl -s "http://localhost:3100/loki/api/v1/query?query=sum(rate({job=\"syslog\"}[1m]))" | \
    jq -r '.data.result[0]?.value[1]' 2>/dev/null)
auth_rate=$(curl -s "http://localhost:3100/loki/api/v1/query?query=sum(rate({job=\"auth\"}[1m]))" | \
    jq -r '.data.result[0]?.value[1]' 2>/dev/null)

echo "Syslog rate: ${syslog_rate:-0} logs/sec"
echo "Auth rate: ${auth_rate:-0} logs/sec"
echo

echo "=== Disk Usage ==="
df -h /var/log
echo

echo "=== Journal Status ==="
journalctl --disk-usage 2>/dev/null || echo "Journal not accessible"
EOF

chmod +x ~/loki-stack/scripts/monitor-system-logs.sh
```

### 7.2 Script de Análise de Segurança

```bash
cat > ~/loki-stack/scripts/security-analysis.sh << 'EOF'
#!/bin/bash

echo "=== Security Log Analysis ==="
echo "Date: $(date)"
echo

echo "=== Failed Login Summary (Last Hour) ==="
curl -s "http://localhost:3100/loki/api/v1/query_range?query={job=\"auth\"} |~ \"(?i)(failed|failure|invalid)\"&start=$(date -d '1 hour ago' -u +%s)000000000&end=$(date -u +%s)000000000&step=300" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | \
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -nr | head -5
echo

echo "=== Sudo Usage (Last Hour) ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"auth\"} |~ \"sudo\"&limit=10" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -5
echo

echo "=== SSH Connections (Last Hour) ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"auth\"} |~ \"sshd.*Accepted\"&limit=10" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -5
echo

echo "=== System Errors (Last Hour) ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=~\"(syslog|kernel|daemon)\"} |~ \"(?i)(error|critical|alert|emergency)\"&limit=10" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -5
EOF

chmod +x ~/loki-stack/scripts/security-analysis.sh
```

---

## 🛠️ Passo 8: Troubleshooting

### 8.1 Verificar Acesso aos Logs

```bash
# Verificar se Promtail pode acessar logs do sistema
docker-compose exec promtail ls -la /var/log/

# Verificar permissões específicas
docker-compose exec promtail cat /var/log/syslog | head -5

# Verificar journal
docker-compose exec promtail journalctl --no-pager -n 5 2>/dev/null || echo "Journal not accessible"

# Verificar targets do Promtail
curl -s http://localhost:9080/targets | jq '.activeTargets[] | select(.labels.job | contains("syslog"))'
```

### 8.2 Debug de Configuração

```bash
# Verificar configuração do Promtail
docker-compose exec promtail cat /etc/promtail/config.yml | grep -A 10 "job_name: syslog"

# Verificar logs do Promtail
docker-compose logs promtail | grep -i "syslog\|auth\|kernel"

# Testar queries específicas
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="syslog"}' \
  --data-urlencode 'limit=3' | jq .
```

---

## ✅ Verificação Final

### Checklist de Logs do Sistema

- [ ] Promtail acessando logs do sistema (/var/log/)
- [ ] Logs do syslog aparecendo no Grafana
- [ ] Logs de autenticação sendo coletados
- [ ] Logs do kernel sendo processados
- [ ] Dashboard do sistema funcionando
- [ ] Alertas de segurança configurados
- [ ] Scripts de monitoramento funcionando

### Comandos de Teste

```bash
# Teste completo
cd ~/loki-stack
./scripts/monitor-system-logs.sh

# Análise de segurança
./scripts/security-analysis.sh

# Gerar logs de teste
logger "Test message from logger command"
sudo logger "Test sudo message"

# Verificar no Grafana
# Query: {job="syslog"} |= "Test message"
```

---

## 🎯 Próximos Passos

1. [[Security/05-Seguranca-Autenticacao|Implementar Segurança e Autenticação]]

---

*✅ Configuração de logs do servidor Linux concluída! Seu sistema agora coleta e monitora todos os logs importantes do sistema.*

