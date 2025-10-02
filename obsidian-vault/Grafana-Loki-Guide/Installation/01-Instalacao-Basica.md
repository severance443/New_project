# 🚀 Instalação Básica do Grafana Loki

> **Tempo estimado:** 15-20 minutos  
> **Dificuldade:** Iniciante  
> **Pré-requisitos:** Docker e Docker Compose instalados

## 📋 Visão Geral

Neste guia, você aprenderá a instalar o Grafana Loki usando Docker Compose de forma simples e eficiente. Vamos configurar:

- **Loki** - Servidor de logs
- **Promtail** - Agente coletor de logs
- **Grafana** - Interface de visualização (opcional)

---

## 🛠️ Passo 1: Preparação do Ambiente

### 1.1 Criar Estrutura de Diretórios

```bash
# Criar diretório principal
mkdir -p ~/loki-stack
cd ~/loki-stack

# Criar subdiretórios
mkdir -p {config,data,logs}
mkdir -p data/{loki,grafana}
mkdir -p config/{loki,promtail,grafana}

# Verificar estrutura
tree ~/loki-stack
```

**Estrutura esperada:**
```
loki-stack/
├── config/
│   ├── loki/
│   ├── promtail/
│   └── grafana/
├── data/
│   ├── loki/
│   └── grafana/
└── logs/
```

### 1.2 Configurar Permissões

```bash
# Definir permissões corretas
sudo chown -R $USER:$USER ~/loki-stack
chmod -R 755 ~/loki-stack

# Permissões especiais para dados do Grafana
sudo chown -R 472:472 ~/loki-stack/data/grafana
```

---

## ⚙️ Passo 2: Configuração do Loki

### 2.1 Criar Arquivo de Configuração do Loki

```bash
cat > ~/loki-stack/config/loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

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

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

# By default, Loki will send anonymous, but uniquely-identifiable usage and configuration
# analytics to Grafana Labs. These statistics are sent to https://stats.grafana.org/
#
# Statistics help us better understand how Loki is used, and they show us performance
# levels for most users. This helps us prioritize features and documentation.
# For more information on what's sent, look at
# https://github.com/grafana/loki/blob/main/pkg/usagestats/stats.go
# Refer to the buildReport method to see what goes into a report.
#
# If you would like to disable reporting, uncomment the following lines:
#analytics:
#  reporting_enabled: false
EOF
```

### 2.2 Validar Configuração do Loki

```bash
# Verificar se o arquivo foi criado corretamente
cat ~/loki-stack/config/loki/loki-config.yml

# Verificar sintaxe YAML (se tiver yamllint instalado)
# yamllint ~/loki-stack/config/loki/loki-config.yml
```

---

## 📝 Passo 3: Configuração do Promtail

### 3.1 Criar Arquivo de Configuração do Promtail

```bash
cat > ~/loki-stack/config/promtail/promtail-config.yml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Logs do sistema local
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  # Logs do Docker (se disponível)
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log

  # Logs personalizados
  - job_name: custom
    static_configs:
      - targets:
          - localhost
        labels:
          job: customlogs
          __path__: /logs/*log
EOF
```

---

## 🐳 Passo 4: Docker Compose

### 4.1 Criar docker-compose.yml

```bash
cat > ~/loki-stack/docker-compose.yml << 'EOF'
version: "3.8"

networks:
  loki:
    driver: bridge

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
      - ./data/loki:/loki
    networks:
      - loki
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
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./logs:/logs:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - loki
    depends_on:
      - loki

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
    volumes:
      - ./data/grafana:/var/lib/grafana
    networks:
      - loki
    depends_on:
      - loki
EOF
```

### 4.2 Validar Docker Compose

```bash
# Validar sintaxe do docker-compose
docker-compose config

# Verificar se as imagens estão disponíveis
docker-compose pull
```

---

## 🚀 Passo 5: Inicialização dos Serviços

### 5.1 Iniciar os Serviços

```bash
# Navegar para o diretório
cd ~/loki-stack

# Iniciar em modo detached (background)
docker-compose up -d

# Verificar status dos containers
docker-compose ps
```

**Saída esperada:**
```
    Name                   Command               State           Ports
-------------------------------------------------------------------------
grafana     /run.sh                          Up      0.0.0.0:3000->3000/tcp
loki        /usr/bin/loki -config.file ...   Up      0.0.0.0:3100->3100/tcp
promtail    /usr/bin/promtail -config. ...   Up
```

### 5.2 Verificar Logs dos Serviços

```bash
# Ver logs de todos os serviços
docker-compose logs

# Ver logs específicos
docker-compose logs loki
docker-compose logs promtail
docker-compose logs grafana

# Seguir logs em tempo real
docker-compose logs -f
```

---

## ✅ Passo 6: Verificação da Instalação

### 6.1 Testar API do Loki

```bash
# Verificar se Loki está respondendo
curl -s http://localhost:3100/ready

# Verificar métricas
curl -s http://localhost:3100/metrics | head -20

# Testar consulta básica
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="varlogs"}' \
  --data-urlencode 'limit=5'
```

### 6.2 Verificar Grafana

```bash
# Aguardar Grafana inicializar
sleep 30

# Testar acesso ao Grafana
curl -s http://localhost:3000/api/health
```

**Acessar via navegador:**
- URL: http://localhost:3000
- Usuário: `admin`
- Senha: `admin123`

### 6.3 Verificar Promtail

```bash
# Verificar se Promtail está coletando logs
docker-compose logs promtail | grep -i "client.*push"

# Verificar targets do Promtail
curl -s http://localhost:9080/targets
```

---

## 🔧 Passo 7: Configuração Inicial do Grafana

### 7.1 Adicionar Loki como Data Source

1. **Acessar Grafana:** http://localhost:3000
2. **Login:** admin / admin123
3. **Ir para:** Configuration → Data Sources
4. **Adicionar:** Loki
5. **URL:** http://loki:3100
6. **Salvar & Testar**

### 7.2 Importar Dashboard Básico

```bash
# Criar dashboard básico para logs
cat > ~/loki-stack/config/grafana/dashboard-logs.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Loki Logs Dashboard",
    "tags": ["loki", "logs"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Recent Logs",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=\"varlogs\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "5s"
  }
}
EOF
```

---

## 🎯 Comandos Úteis

### Gerenciamento dos Serviços

```bash
# Parar serviços
docker-compose stop

# Reiniciar serviços
docker-compose restart

# Parar e remover containers
docker-compose down

# Parar e remover tudo (incluindo volumes)
docker-compose down -v

# Ver uso de recursos
docker stats

# Limpar logs do Docker
docker system prune -f
```

### Monitoramento

```bash
# Verificar espaço em disco
df -h ~/loki-stack/data/

# Verificar logs em tempo real
tail -f ~/loki-stack/logs/*.log

# Verificar conectividade
netstat -tlnp | grep -E "(3100|3000|9080)"
```

---

## ⚠️ Solução de Problemas

### Problema: Container não inicia

```bash
# Verificar logs detalhados
docker-compose logs [service_name]

# Verificar configuração
docker-compose config

# Verificar permissões
ls -la ~/loki-stack/data/
```

### Problema: Loki não recebe logs

```bash
# Verificar configuração do Promtail
docker-compose exec promtail cat /etc/promtail/config.yml

# Verificar conectividade
docker-compose exec promtail wget -qO- http://loki:3100/ready

# Verificar logs do Promtail
docker-compose logs promtail | grep -i error
```

### Problema: Grafana não conecta ao Loki

```bash
# Verificar rede Docker
docker network ls
docker network inspect loki-stack_loki

# Testar conectividade interna
docker-compose exec grafana wget -qO- http://loki:3100/ready
```

---

## ✅ Próximos Passos

Após completar a instalação básica:

1. [[Configuration/02-Configuracao-Inicial|Configuração Inicial Avançada]]
2. [[Docker-Logs/03-Docker-Logs|Configurar Logs do Docker]]
3. [[Server-Logs/04-Server-Logs|Configurar Logs do Servidor]]
4. [[Security/05-Seguranca-Autenticacao|Implementar Segurança]]

---

*✅ Instalação básica concluída! Seu sistema de logs centralizado está funcionando.*

