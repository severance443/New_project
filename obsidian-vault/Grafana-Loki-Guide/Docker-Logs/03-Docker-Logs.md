# 🐳 Configuração de Logs do Docker para Loki

> **Tempo estimado:** 20-30 minutos  
> **Dificuldade:** Intermediário  
> **Pré-requisitos:** Loki instalado e funcionando

## 📋 Visão Geral

Neste guia, você aprenderá a configurar o Docker para enviar logs diretamente para o Grafana Loki, incluindo:

- **Driver de logging do Docker**
- **Configuração de containers individuais**
- **Labels automáticos para containers**
- **Filtragem e parsing de logs**
- **Monitoramento de containers**

---

## 🔧 Passo 1: Configuração do Docker Daemon

### 1.1 Configurar Driver de Logging Global

```bash
# Backup da configuração atual do Docker
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup 2>/dev/null || echo "Arquivo daemon.json não existe ainda"

# Criar/atualizar configuração do Docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels": "service,version,environment"
  },
  "features": {
    "buildkit": true
  }
}
EOF

# Reiniciar Docker daemon
sudo systemctl restart docker

# Verificar se Docker reiniciou corretamente
sudo systemctl status docker
```

### 1.2 Verificar Configuração

```bash
# Verificar configuração do Docker
docker info | grep -A 10 "Logging Driver"

# Testar com container simples
docker run --rm --name test-logging hello-world
docker logs test-logging
```

---

## 📝 Passo 2: Configuração do Promtail para Docker

### 2.1 Atualizar Configuração do Promtail

```bash
# Backup da configuração atual
cp ~/loki-stack/config/promtail/promtail-config.yml ~/loki-stack/config/promtail/promtail-config.yml.backup

# Nova configuração otimizada para Docker
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

  # Logs do Docker - Método 1: Via arquivos de log
  - job_name: docker-containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: ${HOSTNAME}
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      # Parse do JSON do Docker
      - json:
          expressions:
            output: log
            stream: stream
            attrs: attrs
            time: time
      
      # Extrair ID do container do path
      - regex:
          expression: '^/var/lib/docker/containers/(?P<container_id>[^/]+)/.*$'
          source: filename
      
      # Extrair informações dos atributos
      - json:
          expressions:
            container_name: attrs["io.kubernetes.container.name"]
            pod_name: attrs["io.kubernetes.pod.name"]
            namespace: attrs["io.kubernetes.pod.namespace"]
            service: attrs["com.docker.compose.service"]
            project: attrs["com.docker.compose.project"]
            image: attrs["image"]
          source: attrs
      
      # Labels dinâmicos
      - labels:
          container_id:
          stream:
          container_name:
          pod_name:
          namespace:
          service:
          project:
          image:
      
      # Timestamp do Docker
      - timestamp:
          source: time
          format: RFC3339Nano
      
      # Output final
      - output:
          source: output

  # Logs específicos de aplicações Docker
  - job_name: docker-apps
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker-apps
          host: ${HOSTNAME}
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs: attrs
            time: time
      
      # Filtrar apenas containers de aplicação
      - match:
          selector: '{job="docker-apps"}'
          stages:
            - json:
                expressions:
                  service: attrs["com.docker.compose.service"]
                source: attrs
            - drop:
                expression: '.*'
                source: service
                value: ''
      
      # Parse de logs estruturados (JSON)
      - match:
          selector: '{job="docker-apps"} |~ "^\\s*[{].*[}]\\s*$"'
          stages:
            - json:
                expressions:
                  level: level
                  message: message
                  timestamp: timestamp
                  service_name: service
                  trace_id: trace_id
                source: output
            - labels:
                level:
                service_name:
                trace_id:
            - timestamp:
                source: timestamp
                format: RFC3339
            - output:
                source: message

  # Logs de containers específicos (nginx, apache, etc.)
  - job_name: webserver-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: webserver
          host: ${HOSTNAME}
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            attrs: attrs
      
      # Filtrar apenas webservers
      - json:
          expressions:
            image: attrs.image
          source: attrs
      
      - match:
          selector: '{job="webserver"}'
          stages:
            - drop:
                expression: '.*'
                source: image
                value: '(?i).*(nginx|apache|httpd).*'
                drop_counter_reason: "not_webserver"
      
      # Parse de logs do Nginx
      - match:
          selector: '{job="webserver"} |~ ".*nginx.*"'
          stages:
            - regex:
                expression: '^(?P<remote_addr>\S+) - (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<request>\S+) (?P<protocol>\S+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'
                source: output
            - labels:
                method:
                status:
                remote_addr:
            - timestamp:
                source: time_local
                format: '02/Jan/2006:15:04:05 -0700'

  # Logs de banco de dados
  - job_name: database-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: database
          host: ${HOSTNAME}
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            attrs: attrs
      
      - json:
          expressions:
            image: attrs.image
          source: attrs
      
      # Filtrar apenas bancos de dados
      - match:
          selector: '{job="database"}'
          stages:
            - drop:
                expression: '.*'
                source: image
                value: '(?i).*(mysql|postgres|mongodb|redis|elasticsearch).*'
                drop_counter_reason: "not_database"
      
      # Parse específico para PostgreSQL
      - match:
          selector: '{job="database"} |~ ".*postgres.*"'
          stages:
            - regex:
                expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \w+) \[(?P<pid>\d+)\] (?P<level>\w+):\s+(?P<message>.*)$'
                source: output
            - labels:
                level:
                pid:
            - timestamp:
                source: timestamp
                format: '2006-01-02 15:04:05.000 MST'
EOF
```

---

## 🏷️ Passo 3: Configuração de Labels para Containers

### 3.1 Docker Compose com Labels

```bash
# Criar exemplo de docker-compose com labels otimizados
cat > ~/loki-stack/examples/docker-compose-with-labels.yml << 'EOF'
version: '3.8'

services:
  web:
    image: nginx:alpine
    container_name: web-server
    ports:
      - "8080:80"
    labels:
      - "logging=enabled"
      - "service=web"
      - "version=1.0"
      - "environment=production"
      - "team=frontend"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,version,environment,team"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - app-network

  api:
    image: node:16-alpine
    container_name: api-server
    ports:
      - "3001:3000"
    labels:
      - "logging=enabled"
      - "service=api"
      - "version=2.1"
      - "environment=production"
      - "team=backend"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,version,environment,team"
    command: ["node", "server.js"]
    working_dir: /app
    volumes:
      - ./api:/app
    networks:
      - app-network
    depends_on:
      - database

  database:
    image: postgres:13
    container_name: postgres-db
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    labels:
      - "logging=enabled"
      - "service=database"
      - "version=13"
      - "environment=production"
      - "team=backend"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,version,environment,team"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    container_name: redis-cache
    labels:
      - "logging=enabled"
      - "service=cache"
      - "version=7"
      - "environment=production"
      - "team=backend"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,version,environment,team"
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data:
EOF
```

### 3.2 Script para Aplicar Labels em Containers Existentes

```bash
cat > ~/loki-stack/scripts/apply-docker-labels.sh << 'EOF'
#!/bin/bash

# Script para aplicar labels em containers existentes

echo "=== Aplicando labels em containers Docker ==="

# Função para aplicar labels
apply_labels() {
    local container_name=$1
    local service=$2
    local version=$3
    local environment=$4
    local team=$5
    
    echo "Aplicando labels no container: $container_name"
    
    docker update \
        --label service=$service \
        --label version=$version \
        --label environment=$environment \
        --label team=$team \
        --label logging=enabled \
        $container_name
}

# Exemplos de uso - ajuste conforme seus containers
# apply_labels "nginx-proxy" "proxy" "1.0" "production" "devops"
# apply_labels "app-backend" "api" "2.1" "production" "backend"
# apply_labels "app-frontend" "web" "1.5" "production" "frontend"

echo "Para usar este script, descomente e ajuste as linhas apply_labels conforme seus containers"
echo "Exemplo: apply_labels 'container-name' 'service-name' 'version' 'environment' 'team'"
EOF

chmod +x ~/loki-stack/scripts/apply-docker-labels.sh
```

---

## 🔍 Passo 4: Driver Loki para Docker

### 4.1 Instalar Plugin Loki Driver

```bash
# Instalar plugin oficial do Loki para Docker
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions

# Verificar se plugin foi instalado
docker plugin ls
```

### 4.2 Configurar Container com Driver Loki

```bash
# Exemplo de container usando driver Loki diretamente
cat > ~/loki-stack/examples/docker-compose-loki-driver.yml << 'EOF'
version: '3.8'

services:
  app-with-loki-driver:
    image: nginx:alpine
    container_name: nginx-loki
    ports:
      - "8081:80"
    logging:
      driver: loki
      options:
        loki-url: "http://localhost:3100/loki/api/v1/push"
        loki-batch-size: "400"
        loki-batch-wait: "1s"
        loki-timeout: "10s"
        loki-retries: "5"
        loki-min-backoff: "100ms"
        loki-max-backoff: "10s"
        labels: |
          service=nginx
          environment=production
          version=1.0
        loki-external-labels: |
          host=docker-host
          datacenter=dc1

  app-traditional:
    image: nginx:alpine
    container_name: nginx-traditional
    ports:
      - "8082:80"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,environment,version"
    labels:
      - "service=nginx"
      - "environment=production"
      - "version=1.0"
EOF
```

---

## 📊 Passo 5: Dashboards Específicos para Docker

### 5.1 Dashboard de Containers

```bash
cat > ~/loki-stack/config/grafana/provisioning/dashboards/docker-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Docker Containers Logs",
    "tags": ["docker", "containers", "logs"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Container Log Volume",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (service) (rate({job=\"docker\"}[5m]))",
            "refId": "A",
            "legendFormat": "{{service}}"
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
        "title": "Container Status Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (stream) (count_over_time({job=\"docker\"}[1h]))",
            "refId": "A",
            "legendFormat": "{{stream}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Container Logs by Service",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"docker\"} |= \"\"",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "wrapLogMessage": true,
          "enableLogDetails": true
        },
        "gridPos": {"h": 12, "w": 24, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Error Logs by Container",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"docker\"} |~ \"(?i)(error|exception|fail|fatal)\"",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "wrapLogMessage": true,
          "enableLogDetails": true
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20}
      },
      {
        "id": 5,
        "title": "Top Containers by Log Volume",
        "type": "barchart",
        "targets": [
          {
            "expr": "topk(10, sum by (container_name) (count_over_time({job=\"docker\", container_name!=\"\"}[1h])))",
            "refId": "A",
            "legendFormat": "{{container_name}}"
          }
        ],
        "options": {
          "orientation": "horizontal",
          "legend": {"displayMode": "hidden"}
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 28}
      },
      {
        "id": 6,
        "title": "Log Levels Distribution",
        "type": "barchart",
        "targets": [
          {
            "expr": "sum by (level) (count_over_time({job=\"docker\", level!=\"\"}[1h]))",
            "refId": "A",
            "legendFormat": "{{level}}"
          }
        ],
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

## 🔄 Passo 6: Aplicar Configurações

### 6.1 Reiniciar Promtail

```bash
cd ~/loki-stack

# Reiniciar apenas o Promtail
docker-compose restart promtail

# Verificar logs do Promtail
docker-compose logs -f promtail
```

### 6.2 Testar Coleta de Logs

```bash
# Criar containers de teste
cd ~/loki-stack/examples

# Iniciar containers com labels
docker-compose -f docker-compose-with-labels.yml up -d

# Verificar se containers estão rodando
docker-compose -f docker-compose-with-labels.yml ps

# Gerar alguns logs
docker exec web-server nginx -s reload
docker exec api-server echo "Test log message from API"
```

### 6.3 Verificar no Grafana

1. **Acessar Grafana:** http://localhost:3000
2. **Ir para Explore**
3. **Testar queries:**
   ```logql
   # Todos os logs do Docker
   {job="docker"}
   
   # Logs por serviço
   {job="docker", service="web"}
   
   # Logs de erro
   {job="docker"} |~ "(?i)(error|exception|fail)"
   
   # Logs por container
   {job="docker", container_name="web-server"}
   ```

---

## 📈 Passo 7: Monitoramento e Alertas

### 7.1 Alertas para Containers

```bash
cat > ~/loki-stack/config/loki/rules/docker-alerts.yml << 'EOF'
groups:
  - name: docker_alerts
    rules:
      - alert: ContainerHighErrorRate
        expr: |
          sum(rate({job="docker"} |~ "(?i)(error|exception|fail|fatal)" [5m])) by (service) > 5
        for: 2m
        labels:
          severity: warning
          service: "{{ $labels.service }}"
        annotations:
          summary: "High error rate in container {{ $labels.service }}"
          description: "Container {{ $labels.service }} has error rate of {{ $value }} errors/sec"

      - alert: ContainerLogVolumeHigh
        expr: |
          sum(rate({job="docker"}[5m])) by (service) > 100
        for: 5m
        labels:
          severity: warning
          service: "{{ $labels.service }}"
        annotations:
          summary: "High log volume from container {{ $labels.service }}"
          description: "Container {{ $labels.service }} is generating {{ $value }} logs/sec"

      - alert: ContainerNotLogging
        expr: |
          absent_over_time(sum(rate({job="docker"}[1m])) by (service)[10m])
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Container stopped logging"
          description: "No logs received from Docker containers in the last 10 minutes"

      - alert: ContainerOOMKilled
        expr: |
          increase({job="docker"} |~ "(?i)killed.*oom" [5m]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Container killed by OOM"
          description: "Container was killed due to out of memory"
EOF
```

### 7.2 Script de Monitoramento Docker

```bash
cat > ~/loki-stack/scripts/monitor-docker-logs.sh << 'EOF'
#!/bin/bash

echo "=== Docker Logs Monitoring ==="
echo "Date: $(date)"
echo

echo "=== Running Containers ==="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo

echo "=== Container Log Sizes ==="
for container in $(docker ps --format "{{.Names}}"); do
    log_file=$(docker inspect $container | jq -r '.[0].LogPath')
    if [ -f "$log_file" ]; then
        size=$(du -h "$log_file" | cut -f1)
        echo "$container: $size"
    fi
done
echo

echo "=== Recent Docker Logs in Loki ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"docker\"}&limit=10" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -5
echo

echo "=== Docker Error Rate ==="
error_count=$(curl -s "http://localhost:3100/loki/api/v1/query?query=sum(count_over_time({job=\"docker\"} |~ \"(?i)(error|exception|fail)\" [5m]))" | \
    jq -r '.data.result[0]?.value[1]' 2>/dev/null)
echo "Errors in last 5 minutes: ${error_count:-0}"
EOF

chmod +x ~/loki-stack/scripts/monitor-docker-logs.sh
```

---

## 🛠️ Passo 8: Troubleshooting

### 8.1 Problemas Comuns

```bash
# Verificar se Promtail está lendo logs do Docker
docker-compose exec promtail ls -la /var/lib/docker/containers/

# Verificar permissões
docker-compose exec promtail ls -la /var/lib/docker/containers/*/

# Testar conectividade com Loki
docker-compose exec promtail wget -qO- http://loki:3100/ready

# Verificar configuração do Promtail
docker-compose exec promtail cat /etc/promtail/config.yml
```

### 8.2 Debug de Logs

```bash
# Verificar logs específicos do Promtail
docker-compose logs promtail | grep -i docker

# Verificar targets do Promtail
curl -s http://localhost:9080/targets | jq .

# Testar query no Loki
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode 'limit=5' | jq .
```

---

## ✅ Verificação Final

### Checklist Docker Logs

- [ ] Promtail configurado para ler logs do Docker
- [ ] Containers com labels apropriados
- [ ] Logs aparecendo no Grafana
- [ ] Dashboard Docker funcionando
- [ ] Alertas configurados
- [ ] Monitoramento automatizado

### Comandos de Teste

```bash
# Teste completo
cd ~/loki-stack
./scripts/monitor-docker-logs.sh

# Gerar logs de teste
docker run --rm --name test-logs \
  --label service=test \
  --label environment=dev \
  alpine sh -c 'echo "INFO: Test message"; echo "ERROR: Test error"; sleep 5'

# Verificar no Grafana
# Query: {job="docker", service="test"}
```

---

## 🎯 Próximos Passos

1. [[Server-Logs/04-Server-Logs|Configurar Logs do Servidor Linux]]
2. [[Security/05-Seguranca-Autenticacao|Implementar Segurança]]

---

*✅ Configuração de logs do Docker concluída! Seus containers agora enviam logs para o Loki automaticamente.*

