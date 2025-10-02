#!/bin/bash

# ============================================================================
# LOKI STACK - QUICK START
# ============================================================================
# Script rápido para testar o sistema após instalação
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/loki-stack"

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se instalação existe
if [[ ! -d "$INSTALL_DIR" ]]; then
    error "Instalação não encontrada em $INSTALL_DIR"
    echo "Execute primeiro: ./deploy-loki-stack.sh"
    exit 1
fi

cd "$INSTALL_DIR"

echo -e "${BLUE}"
echo "============================================================================"
echo "                         LOKI STACK - QUICK START"
echo "============================================================================"
echo -e "${NC}"

# Verificar Docker
if ! command -v docker >/dev/null 2>&1; then
    error "Docker não encontrado. Execute o script de deploy primeiro."
    exit 1
fi

# Verificar se serviços estão rodando
log "Verificando status dos serviços..."
if ! docker-compose ps | grep -q "Up"; then
    warn "Alguns serviços não estão rodando. Iniciando..."
    docker-compose up -d
    sleep 20
fi

# Status dos containers
echo -e "${BLUE}📦 Status dos Containers:${NC}"
docker-compose ps
echo

# Verificar saúde dos serviços
log "Verificando saúde dos serviços..."

# Loki
echo -n "🔍 Loki: "
if curl -s http://localhost:3100/ready | grep -q "ready"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Grafana
echo -n "📊 Grafana: "
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Traefik
echo -n "🔀 Traefik: "
if curl -s http://localhost:8080/api/version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo

# Gerar logs de teste
log "Gerando logs de teste..."
mkdir -p logs
echo "$(date) INFO Quick start test - system operational" >> logs/test.log
echo "$(date) WARN Quick start test - warning message" >> logs/test.log
echo "$(date) ERROR Quick start test - error message" >> logs/test.log
logger "Quick start test message from system logger"

# Aguardar logs serem processados
sleep 5

# Testar queries
log "Testando queries no Loki..."

echo -n "📝 Logs de teste: "
if curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"custom\"}" | grep -q "test"; then
    echo -e "${GREEN}✅ Encontrados${NC}"
else
    echo -e "${YELLOW}⚠️  Aguardando processamento${NC}"
fi

echo -n "🔐 Logs do sistema: "
if curl -s "http://localhost:3100/loki/api/v1/query?query={job=\"syslog\"}" | grep -q "values"; then
    echo -e "${GREEN}✅ Coletando${NC}"
else
    echo -e "${YELLOW}⚠️  Verificar permissões${NC}"
fi

# Mostrar estatísticas
echo
log "Estatísticas de ingestão..."
rate=$(curl -s "http://localhost:3100/loki/api/v1/query?query=sum(rate({job=~\".%2B\"}[1m]))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
echo "📈 Taxa de ingestão: ${rate} logs/sec"

# Mostrar uso de disco
echo
log "Uso de disco..."
df -h data/ | tail -1

echo
echo -e "${BLUE}🌐 URLs de Acesso:${NC}"
echo "• Grafana:  https://grafana.localhost (admin/admin123)"
echo "• Loki API: https://loki.localhost"
echo "• Traefik:  https://traefik.localhost (admin/admin123)"
echo

echo -e "${BLUE}🔍 Queries de Exemplo para Testar no Grafana:${NC}"
echo "• Todos os logs: {job=~\".+\"}"
echo "• Logs de erro: {job=~\".+\"} |~ \"(?i)(error|fail|exception)\""
echo "• Logs do sistema: {job=\"syslog\"}"
echo "• Logs de autenticação: {job=\"auth\"}"
echo "• Logs de teste: {job=\"custom\"} |= \"test\""
echo

echo -e "${BLUE}📊 Próximos Passos:${NC}"
echo "1. Abra https://grafana.localhost no navegador"
echo "2. Faça login com admin/admin123"
echo "3. Vá para 'Explore' e teste as queries acima"
echo "4. Verifique os dashboards em 'Dashboards'"
echo "5. Configure alertas se necessário"
echo

echo -e "${GREEN}✅ Quick start concluído! Sistema está pronto para uso.${NC}"
