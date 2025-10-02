# 🔐 Segurança e Autenticação para Grafana Loki

> **Tempo estimado:** 40-50 minutos  
> **Dificuldade:** Avançado  
> **Pré-requisitos:** Loki funcionando, conhecimento básico de reverse proxy

## 📋 Visão Geral

Neste guia, você aprenderá a implementar segurança robusta para seu stack Loki, incluindo:

- **Traefik Reverse Proxy** com SSL automático
- **Authentik SSO** para autenticação centralizada
- **Autenticação HTTP básica** como alternativa
- **Configuração de HTTPS** e certificados
- **Controle de acesso** e permissões
- **Monitoramento de segurança**

---

## 🚀 Passo 1: Configuração do Traefik Reverse Proxy

### 1.1 Estrutura de Diretórios para Traefik

```bash
# Criar estrutura para Traefik
mkdir -p ~/loki-stack/traefik/{config,data,logs}
mkdir -p ~/loki-stack/traefik/data/certificates

# Configurar permissões
chmod 600 ~/loki-stack/traefik/data/certificates
```

### 1.2 Configuração do Traefik

```bash
# Configuração principal do Traefik
cat > ~/loki-stack/traefik/traefik.yml << 'EOF'
# Configuração global
global:
  checkNewVersion: false
  sendAnonymousUsage: false

# Pontos de entrada
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

# Certificados SSL automáticos
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com  # ALTERE ESTE EMAIL
      storage: /certificates/acme.json
      httpChallenge:
        entryPoint: web

# Providers
providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: loki_default
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

# API e Dashboard
api:
  dashboard: true
  debug: false

# Logs
log:
  level: INFO
  filePath: "/logs/traefik.log"

accessLog:
  filePath: "/logs/access.log"
  bufferingSize: 100

# Métricas
metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
EOF
```

### 1.3 Configuração Dinâmica do Traefik

```bash
# Configuração dinâmica para middlewares
cat > ~/loki-stack/traefik/config/dynamic.yml << 'EOF'
# Middlewares de segurança
http:
  middlewares:
    # Headers de segurança
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
          Feature-Policy: "camera 'none'; geolocation 'none'; microphone 'none'; payment 'none'; usb 'none'; vr 'none';"
          Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self' ws: wss:; frame-ancestors 'none';"

    # Autenticação HTTP básica
    basic-auth:
      basicAuth:
        users:
          - "admin:$2y$10$2b2cu2Fw8nJr2Aw.UrW2/.6eYXvNf0VhGrp8ow3/Oy6.5.5.5.5.5"  # admin:admin123
          - "viewer:$2y$10$viewer.hash.here"  # viewer:viewer123

    # Rate limiting
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
        period: 1m

    # IP Whitelist (opcional)
    ip-whitelist:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"
          - "10.0.0.0/8"
          - "172.16.0.0/12"
          - "192.168.0.0/16"

# TLS Options
tls:
  options:
    default:
      minVersion: "VersionTLS12"
      cipherSuites:
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256"
      curvePreferences:
        - "CurveP521"
        - "CurveP384"
EOF
```

---

## 🔑 Passo 2: Configuração do Authentik SSO

### 2.1 Estrutura para Authentik

```bash
# Criar estrutura para Authentik
mkdir -p ~/loki-stack/authentik/{config,data,logs}
mkdir -p ~/loki-stack/authentik/data/{media,templates,certs}

# Gerar chaves secretas
openssl rand -base64 32 > ~/loki-stack/authentik/secret_key
openssl rand -base64 32 > ~/loki-stack/authentik/postgres_password
```

### 2.2 Configuração do Authentik

```bash
# Arquivo de ambiente para Authentik
cat > ~/loki-stack/authentik/.env << 'EOF'
# PostgreSQL
POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
POSTGRES_USER=authentik
POSTGRES_DB=authentik

# Authentik
AUTHENTIK_SECRET_KEY_FILE=/run/secrets/authentik_secret_key
AUTHENTIK_ERROR_REPORTING__ENABLED=false
AUTHENTIK_DISABLE_UPDATE_CHECK=true
AUTHENTIK_DISABLE_STARTUP_ANALYTICS=true

# Email (opcional)
AUTHENTIK_EMAIL__HOST=localhost
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=
AUTHENTIK_EMAIL__PASSWORD=
AUTHENTIK_EMAIL__USE_TLS=false
AUTHENTIK_EMAIL__USE_SSL=false
AUTHENTIK_EMAIL__TIMEOUT=10
AUTHENTIK_EMAIL__FROM=authentik@localhost

# Redis
AUTHENTIK_REDIS__HOST=redis
AUTHENTIK_REDIS__PASSWORD=
EOF
```

---

## 🐳 Passo 3: Docker Compose Completo com Segurança

### 3.1 Docker Compose Seguro

```bash
cat > ~/loki-stack/docker-compose.yml << 'EOF'
version: "3.8"

networks:
  loki:
    driver: bridge
  traefik:
    driver: bridge

volumes:
  grafana-data:
  loki-data:
  postgres-data:
  redis-data:

secrets:
  postgres_password:
    file: ./authentik/postgres_password
  authentik_secret_key:
    file: ./authentik/secret_key

services:
  # ========== TRAEFIK REVERSE PROXY ==========
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard (remover em produção)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/config/dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./traefik/data/certificates:/certificates
      - ./traefik/logs:/logs
    networks:
      - traefik
      - loki
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.localhost`)"  # ALTERE O DOMÍNIO
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=basic-auth@file"

  # ========== LOKI ==========
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
      - "traefik.http.routers.loki.rule=Host(`loki.localhost`)"  # ALTERE O DOMÍNIO
      - "traefik.http.routers.loki.entrypoints=websecure"
      - "traefik.http.routers.loki.tls.certresolver=letsencrypt"
      - "traefik.http.routers.loki.middlewares=security-headers@file,rate-limit@file"
      - "traefik.http.services.loki.loadbalancer.server.port=3100"
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # ========== PROMTAIL ==========
  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./config/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./logs:/logs:ro
      - /run/systemd/journal:/run/systemd/journal:ro
      - /var/log/journal:/var/log/journal:ro
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

  # ========== GRAFANA ==========
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
      # OAuth com Authentik
      - GF_AUTH_GENERIC_OAUTH_ENABLED=true
      - GF_AUTH_GENERIC_OAUTH_NAME=Authentik
      - GF_AUTH_GENERIC_OAUTH_CLIENT_ID=grafana
      - GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=your-client-secret
      - GF_AUTH_GENERIC_OAUTH_SCOPES=openid profile email
      - GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://auth.localhost/application/o/authorize/
      - GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://auth.localhost/application/o/token/
      - GF_AUTH_GENERIC_OAUTH_API_URL=https://auth.localhost/application/o/userinfo/
      - GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true
      - GF_AUTH_GENERIC_OAUTH_AUTO_LOGIN=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - loki
      - traefik
    depends_on:
      loki:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.localhost`)"  # ALTERE O DOMÍNIO
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
      - "traefik.http.routers.grafana.middlewares=security-headers@file"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  # ========== AUTHENTIK ==========
  postgresql:
    image: postgres:15-alpine
    container_name: authentik-postgres
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 5s
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
      POSTGRES_USER: authentik
      POSTGRES_DB: authentik
    secrets:
      - postgres_password
    networks:
      - loki

  redis:
    image: redis:alpine
    container_name: authentik-redis
    restart: unless-stopped
    command: --save 60 1 --loglevel warning
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 3s
    volumes:
      - redis-data:/data
    networks:
      - loki

  authentik-server:
    image: ghcr.io/goauthentik/authentik:2023.10.4
    container_name: authentik-server
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD_FILE: /run/secrets/postgres_password
      AUTHENTIK_SECRET_KEY_FILE: /run/secrets/authentik_secret_key
    volumes:
      - ./authentik/data/media:/media
      - ./authentik/data/templates:/templates
    env_file:
      - ./authentik/.env
    secrets:
      - postgres_password
      - authentik_secret_key
    networks:
      - loki
      - traefik
    depends_on:
      - postgresql
      - redis
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authentik.rule=Host(`auth.localhost`)"  # ALTERE O DOMÍNIO
      - "traefik.http.routers.authentik.entrypoints=websecure"
      - "traefik.http.routers.authentik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.authentik.middlewares=security-headers@file"
      - "traefik.http.services.authentik.loadbalancer.server.port=9000"

  authentik-worker:
    image: ghcr.io/goauthentik/authentik:2023.10.4
    container_name: authentik-worker
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD_FILE: /run/secrets/postgres_password
      AUTHENTIK_SECRET_KEY_FILE: /run/secrets/authentik_secret_key
    user: root
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./authentik/data/media:/media
      - ./authentik/data/templates:/templates
      - ./authentik/data/certs:/certs
    env_file:
      - ./authentik/.env
    secrets:
      - postgres_password
      - authentik_secret_key
    networks:
      - loki
    depends_on:
      - postgresql
      - redis
EOF
```

---

## 🔐 Passo 4: Configuração de Autenticação HTTP Básica (Alternativa Simples)

### 4.1 Gerar Senhas Hash

```bash
# Instalar htpasswd se não estiver disponível
sudo apt-get update && sudo apt-get install -y apache2-utils

# Gerar hash para usuários
echo "=== Gerando hashes de senha ==="
echo -n "admin:" > ~/loki-stack/traefik/.htpasswd
htpasswd -nb admin admin123 | cut -d: -f2 >> ~/loki-stack/traefik/.htpasswd

echo -n "viewer:" >> ~/loki-stack/traefik/.htpasswd
htpasswd -nb viewer viewer123 | cut -d: -f2 >> ~/loki-stack/traefik/.htpasswd

# Mostrar arquivo gerado
cat ~/loki-stack/traefik/.htpasswd
```

### 4.2 Docker Compose Simplificado (Apenas HTTP Basic Auth)

```bash
cat > ~/loki-stack/docker-compose-simple-auth.yml << 'EOF'
version: "3.8"

networks:
  loki:
    driver: bridge

volumes:
  grafana-data:
  loki-data:

services:
  # ========== TRAEFIK ==========
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./traefik/config/dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./traefik/data/certificates:/certificates
      - ./traefik/logs:/logs
    networks:
      - loki
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=your-email@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/certificates/acme.json"

  # ========== LOKI ==========
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
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.loki.rule=Host(`loki.localhost`)"
      - "traefik.http.routers.loki.entrypoints=websecure"
      - "traefik.http.routers.loki.tls.certresolver=letsencrypt"
      - "traefik.http.routers.loki.middlewares=basic-auth@file"
      - "traefik.http.services.loki.loadbalancer.server.port=3100"

  # ========== GRAFANA ==========
  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - loki
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.localhost`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  # ========== PROMTAIL ==========
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
    user: root
    depends_on:
      - loki
EOF
```

---

## 🛡️ Passo 5: Configurações de Segurança Avançadas

### 5.1 Configuração de Firewall

```bash
# Script de configuração do firewall
cat > ~/loki-stack/scripts/setup-firewall.sh << 'EOF'
#!/bin/bash

echo "=== Configurando Firewall para Loki Stack ==="

# Instalar UFW se não estiver instalado
sudo apt-get update
sudo apt-get install -y ufw

# Resetar regras
sudo ufw --force reset

# Políticas padrão
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH (ajuste a porta se necessário)
sudo ufw allow 22/tcp

# HTTP e HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Portas específicas do Loki (apenas se necessário acesso direto)
# sudo ufw allow from 192.168.1.0/24 to any port 3100
# sudo ufw allow from 192.168.1.0/24 to any port 3000

# Ativar firewall
sudo ufw --force enable

# Mostrar status
sudo ufw status verbose

echo "=== Firewall configurado ==="
EOF

chmod +x ~/loki-stack/scripts/setup-firewall.sh
```

### 5.2 Configuração de Fail2Ban

```bash
# Script para configurar Fail2Ban
cat > ~/loki-stack/scripts/setup-fail2ban.sh << 'EOF'
#!/bin/bash

echo "=== Configurando Fail2Ban ==="

# Instalar Fail2Ban
sudo apt-get update
sudo apt-get install -y fail2ban

# Configuração para Traefik
sudo tee /etc/fail2ban/filter.d/traefik-auth.conf << 'FILTER_EOF'
[Definition]
failregex = ^<HOST> - \S+ \[\] \"(GET|POST|HEAD).*\" 401 \d+ \"-\" \".*\"$
ignoreregex =
FILTER_EOF

# Jail para Traefik
sudo tee /etc/fail2ban/jail.d/traefik.conf << 'JAIL_EOF'
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /home/*/loki-stack/traefik/logs/access.log
maxretry = 5
bantime = 3600
findtime = 600
JAIL_EOF

# Reiniciar Fail2Ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# Verificar status
sudo fail2ban-client status

echo "=== Fail2Ban configurado ==="
EOF

chmod +x ~/loki-stack/scripts/setup-fail2ban.sh
```

---

## 📊 Passo 6: Monitoramento de Segurança

### 6.1 Dashboard de Segurança

```bash
cat > ~/loki-stack/config/grafana/provisioning/dashboards/security-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Security Monitoring Dashboard",
    "tags": ["security", "monitoring", "auth"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Authentication Attempts",
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
                {"color": "yellow", "value": 5},
                {"color": "red", "value": 20}
              ]
            },
            "unit": "attempts/sec"
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Failed Logins",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate({job=\"auth\"} |~ \"(?i)(failed|failure|invalid)\" [5m]))",
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
                {"color": "red", "value": 5}
              ]
            },
            "unit": "failures/sec"
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Traefik Access Logs",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate({filename=~\".*traefik.*access.*\"}[5m]))",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "requests/sec"
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0}
      },
      {
        "id": 4,
        "title": "HTTP Status Codes",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (status) (count_over_time({filename=~\".*traefik.*access.*\"} | regexp \"\\\\s(?P<status>\\\\d{3})\\\\s\" [1h]))",
            "refId": "A",
            "legendFormat": "{{status}}"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0}
      },
      {
        "id": 5,
        "title": "Recent Failed Login Attempts",
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
        "gridPos": {"h": 10, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 6,
        "title": "Suspicious Activity",
        "type": "logs",
        "targets": [
          {
            "expr": "{job=~\"(auth|syslog)\"} |~ \"(?i)(sudo|su |root|admin)\" |~ \"(?i)(fail|error|denied)\"",
            "refId": "A"
          }
        ],
        "options": {
          "showTime": true,
          "showLabels": true,
          "wrapLogMessage": true,
          "enableLogDetails": true
        },
        "gridPos": {"h": 10, "w": 12, "x": 12, "y": 8}
      },
      {
        "id": 7,
        "title": "Top Source IPs (Failed Logins)",
        "type": "barchart",
        "targets": [
          {
            "expr": "topk(10, sum by (source_ip) (count_over_time({job=\"auth\", source_ip!=\"\"} |~ \"(?i)(failed|failure|invalid)\" [1h])))",
            "refId": "A",
            "legendFormat": "{{source_ip}}"
          }
        ],
        "options": {
          "orientation": "horizontal",
          "legend": {"displayMode": "hidden"}
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 18}
      },
      {
        "id": 8,
        "title": "Authentication Timeline",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum(rate({job=\"auth\"}[1m]))",
            "refId": "A",
            "legendFormat": "Total Auth Events"
          },
          {
            "expr": "sum(rate({job=\"auth\"} |~ \"(?i)(failed|failure|invalid)\" [1m]))",
            "refId": "B",
            "legendFormat": "Failed Attempts"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "events/sec"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 18}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s"
  }
}
EOF
```

### 6.2 Alertas de Segurança

```bash
cat > ~/loki-stack/config/loki/rules/security-alerts.yml << 'EOF'
groups:
  - name: security_alerts
    rules:
      - alert: HighFailedLoginRate
        expr: |
          sum(rate({job="auth"} |~ "(?i)(failed|failure|invalid)" [5m])) > 10
        for: 2m
        labels:
          severity: critical
          category: security
        annotations:
          summary: "High failed login rate detected"
          description: "{{ $value }} failed login attempts per second"

      - alert: BruteForceAttack
        expr: |
          sum by (source_ip) (rate({job="auth", source_ip!=""} |~ "(?i)(failed|failure|invalid)" [5m])) > 5
        for: 1m
        labels:
          severity: critical
          category: security
        annotations:
          summary: "Potential brute force attack from {{ $labels.source_ip }}"
          description: "{{ $value }} failed attempts per second from IP {{ $labels.source_ip }}"

      - alert: UnauthorizedAccess
        expr: |
          sum(rate({filename=~".*traefik.*access.*"} |~ " 401 " [5m])) > 5
        for: 2m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "High number of unauthorized access attempts"
          description: "{{ $value }} 401 responses per second"

      - alert: SuspiciousUserActivity
        expr: |
          sum(rate({job="auth"} |~ "(?i)(sudo|su |root)" [5m])) > 20
        for: 3m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "High privilege escalation activity"
          description: "{{ $value }} privilege escalation attempts per second"

      - alert: TraefikDown
        expr: |
          absent(up{job="traefik"})
        for: 1m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "Traefik reverse proxy is down"
          description: "Traefik has been down for more than 1 minute"

      - alert: CertificateExpiring
        expr: |
          sum(rate({filename=~".*traefik.*"} |~ "(?i)(certificate.*expir|cert.*expir)" [5m])) > 0
        for: 0m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "SSL certificate expiring soon"
          description: "SSL certificate expiration warnings detected"
EOF
```

---

## 🚀 Passo 7: Implementação

### 7.1 Escolher Método de Autenticação

```bash
# Opção 1: Implementação completa com Authentik
cd ~/loki-stack
docker-compose up -d

# Opção 2: Implementação simples com HTTP Basic Auth
cd ~/loki-stack
docker-compose -f docker-compose-simple-auth.yml up -d
```

### 7.2 Configurar Domínios (Desenvolvimento Local)

```bash
# Adicionar entradas ao /etc/hosts para teste local
sudo tee -a /etc/hosts << 'EOF'

# Loki Stack
127.0.0.1 loki.localhost
127.0.0.1 grafana.localhost
127.0.0.1 traefik.localhost
127.0.0.1 auth.localhost
EOF
```

### 7.3 Verificar Implementação

```bash
# Verificar serviços
docker-compose ps

# Testar conectividade
curl -k https://loki.localhost/ready
curl -k https://grafana.localhost/api/health
curl -k https://traefik.localhost/api/version

# Verificar logs
docker-compose logs traefik | tail -20
docker-compose logs authentik-server | tail -20
```

---

## 🔧 Passo 8: Configuração Pós-Implementação

### 8.1 Configurar Authentik (Se Usando)

1. **Acessar Authentik:** https://auth.localhost
2. **Login inicial:** akadmin / (senha gerada automaticamente)
3. **Criar usuários e grupos**
4. **Configurar aplicação Grafana**
5. **Configurar políticas de acesso**

### 8.2 Testar Autenticação

```bash
# Testar autenticação HTTP básica
curl -u admin:admin123 https://loki.localhost/ready

# Testar sem autenticação (deve falhar)
curl https://loki.localhost/ready

# Verificar headers de segurança
curl -I https://grafana.localhost
```

---

## 📈 Passo 9: Scripts de Monitoramento

### 9.1 Script de Monitoramento de Segurança

```bash
cat > ~/loki-stack/scripts/security-monitor.sh << 'EOF'
#!/bin/bash

echo "=== Security Monitoring Report ==="
echo "Date: $(date)"
echo

echo "=== Service Status ==="
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo

echo "=== Recent Failed Logins ==="
curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"auth\"} |~ \"(?i)(failed|failure|invalid)\"&limit=5" | \
    jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -3
echo

echo "=== Traefik Access Summary ==="
if [ -f ~/loki-stack/traefik/logs/access.log ]; then
    echo "Total requests today: $(grep "$(date +%d/%b/%Y)" ~/loki-stack/traefik/logs/access.log | wc -l)"
    echo "4xx errors today: $(grep "$(date +%d/%b/%Y)" ~/loki-stack/traefik/logs/access.log | grep -E " 4[0-9]{2} " | wc -l)"
    echo "5xx errors today: $(grep "$(date +%d/%b/%Y)" ~/loki-stack/traefik/logs/access.log | grep -E " 5[0-9]{2} " | wc -l)"
fi
echo

echo "=== Certificate Status ==="
if [ -f ~/loki-stack/traefik/data/certificates/acme.json ]; then
    echo "ACME certificates file exists"
    ls -la ~/loki-stack/traefik/data/certificates/acme.json
else
    echo "No ACME certificates found"
fi
echo

echo "=== Firewall Status ==="
sudo ufw status 2>/dev/null || echo "UFW not configured"
echo

echo "=== Fail2Ban Status ==="
sudo fail2ban-client status 2>/dev/null || echo "Fail2Ban not configured"
EOF

chmod +x ~/loki-stack/scripts/security-monitor.sh
```

---

## ✅ Verificação Final

### Checklist de Segurança

- [ ] Traefik configurado com SSL automático
- [ ] Autenticação funcionando (HTTP Basic ou Authentik)
- [ ] Headers de segurança aplicados
- [ ] Firewall configurado
- [ ] Fail2Ban configurado (opcional)
- [ ] Dashboard de segurança funcionando
- [ ] Alertas de segurança configurados
- [ ] Monitoramento automatizado ativo

### Comandos de Teste

```bash
# Teste completo de segurança
cd ~/loki-stack
./scripts/security-monitor.sh

# Testar autenticação
curl -k -u admin:admin123 https://loki.localhost/ready

# Verificar headers de segurança
curl -I -k https://grafana.localhost

# Acessar interfaces web
# Grafana: https://grafana.localhost
# Loki: https://loki.localhost (com auth)
# Traefik: https://traefik.localhost (com auth)
# Authentik: https://auth.localhost (se configurado)
```

---

## 🎯 Considerações Finais

### ⚠️ Importante para Produção

1. **Altere todas as senhas padrão**
2. **Configure domínios reais** (não .localhost)
3. **Use certificados válidos**
4. **Configure backup** dos dados
5. **Monitore logs de segurança** regularmente
6. **Mantenha sistema atualizado**

### 🔄 Manutenção Regular

- Verificar certificados SSL mensalmente
- Revisar logs de segurança semanalmente
- Atualizar senhas trimestralmente
- Backup de configurações mensalmente

---

<function_calls>
<invoke name="todo_write">
<parameter name="merge">true

