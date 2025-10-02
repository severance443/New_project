#!/bin/bash

# ============================================================================
# LOKI STACK - TROUBLESHOOTING
# ============================================================================
# Script para diagnóstico e resolução de problemas
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

show_help() {
    echo "Uso: $0 [opção]"
    echo
    echo "Opções:"
    echo "  --full      Diagnóstico completo"
    echo "  --logs      Mostrar logs dos serviços"
    echo "  --fix       Tentar corrigir problemas comuns"
    echo "  --reset     Reiniciar todos os serviços"
    echo "  --clean     Limpar dados e reiniciar"
    echo "  --help      Mostrar esta ajuda"
    echo
}

check_installation() {
    log "Verificando instalação..."
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "Instalação não encontrada em $INSTALL_DIR"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        error "docker-compose.yml não encontrado"
        exit 1
    fi
    
    info "Instalação encontrada ✓"
}

check_docker() {
    log "Verificando Docker..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker não instalado"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon não está rodando"
        return 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose não instalado"
        return 1
    fi
    
    info "Docker OK ✓"
    return 0
}

check_containers() {
    log "Verificando containers..."
    
    echo "Status dos containers:"
    docker-compose ps
    echo
    
    # Verificar containers específicos
    containers=("loki" "promtail" "grafana" "traefik")
    
    for container in "${containers[@]}"; do
        if docker-compose ps | grep -q "$container.*Up"; then
            echo -e "✅ $container: ${GREEN}Running${NC}"
        else
            echo -e "❌ $container: ${RED}Down${NC}"
        fi
    done
    echo
}

check_services() {
    log "Verificando serviços..."
    
    # Loki
    echo -n "🔍 Loki (http://localhost:3100): "
    if curl -s --max-time 5 http://localhost:3100/ready | grep -q "ready"; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    # Grafana
    echo -n "📊 Grafana (http://localhost:3000): "
    if curl -s --max-time 5 http://localhost:3000/api/health | grep -q "ok"; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    # Traefik
    echo -n "🔀 Traefik (http://localhost:8080): "
    if curl -s --max-time 5 http://localhost:8080/api/version >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    echo
}

check_logs_ingestion() {
    log "Verificando ingestão de logs..."
    
    # Verificar se Promtail está enviando logs
    echo -n "📝 Promtail targets: "
    if curl -s http://localhost:9080/targets 2>/dev/null | grep -q "ready"; then
        echo -e "${GREEN}✅ Active${NC}"
    else
        echo -e "${RED}❌ No targets${NC}"
    fi
    
    # Verificar taxa de ingestão
    echo -n "📈 Log ingestion rate: "
    rate=$(curl -s "http://localhost:3100/loki/api/v1/query?query=sum(rate({job=~\".%2B\"}[1m]))" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    if [[ "$rate" != "0" ]] && [[ "$rate" != "null" ]]; then
        echo -e "${GREEN}${rate} logs/sec${NC}"
    else
        echo -e "${YELLOW}0 logs/sec${NC}"
    fi
    
    echo
}

check_disk_space() {
    log "Verificando espaço em disco..."
    
    echo "Uso de disco:"
    df -h "$INSTALL_DIR" | tail -1
    echo
    
    echo "Tamanho dos dados:"
    du -sh "$INSTALL_DIR"/data/* 2>/dev/null || echo "Sem dados ainda"
    echo
}

check_permissions() {
    log "Verificando permissões..."
    
    # Verificar permissões dos logs do sistema
    echo -n "📁 /var/log access: "
    if [[ -r /var/log/syslog ]]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ No access${NC}"
    fi
    
    # Verificar permissões do Docker
    echo -n "🐳 Docker socket: "
    if [[ -r /var/run/docker.sock ]]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ No access${NC}"
    fi
    
    echo
}

check_network() {
    log "Verificando rede..."
    
    # Verificar portas
    ports=(80 443 3000 3100 8080 9080)
    
    for port in "${ports[@]}"; do
        echo -n "🌐 Port $port: "
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✅ Open${NC}"
        else
            echo -e "${YELLOW}⚠️  Closed${NC}"
        fi
    done
    
    echo
}

show_logs() {
    log "Mostrando logs dos serviços..."
    
    echo -e "${BLUE}=== LOKI LOGS ===${NC}"
    docker-compose logs --tail=20 loki
    echo
    
    echo -e "${BLUE}=== PROMTAIL LOGS ===${NC}"
    docker-compose logs --tail=20 promtail
    echo
    
    echo -e "${BLUE}=== GRAFANA LOGS ===${NC}"
    docker-compose logs --tail=20 grafana
    echo
    
    echo -e "${BLUE}=== TRAEFIK LOGS ===${NC}"
    docker-compose logs --tail=20 traefik
    echo
}

fix_common_issues() {
    log "Tentando corrigir problemas comuns..."
    
    # Corrigir permissões
    info "Corrigindo permissões..."
    sudo chown -R $USER:$USER "$INSTALL_DIR" 2>/dev/null || true
    chmod -R 755 "$INSTALL_DIR"
    
    # Adicionar usuário aos grupos necessários
    info "Verificando grupos do usuário..."
    sudo usermod -a -G docker $USER 2>/dev/null || true
    sudo usermod -a -G adm $USER 2>/dev/null || true
    sudo usermod -a -G syslog $USER 2>/dev/null || true
    
    # Reiniciar containers com problemas
    info "Reiniciando containers..."
    docker-compose restart
    
    # Aguardar serviços
    info "Aguardando serviços ficarem prontos..."
    sleep 30
    
    log "Correções aplicadas ✓"
}

reset_services() {
    log "Reiniciando todos os serviços..."
    
    docker-compose down
    sleep 5
    docker-compose up -d
    
    info "Aguardando serviços ficarem prontos..."
    sleep 30
    
    log "Serviços reiniciados ✓"
}

clean_and_restart() {
    log "Limpando dados e reiniciando..."
    
    read -p "⚠️  Isso irá remover todos os dados de logs. Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operação cancelada."
        return
    fi
    
    # Parar serviços
    docker-compose down
    
    # Remover volumes
    docker-compose down -v
    
    # Limpar dados locais
    rm -rf data/*
    
    # Reiniciar
    docker-compose up -d
    
    info "Aguardando serviços ficarem prontos..."
    sleep 30
    
    log "Sistema limpo e reiniciado ✓"
}

full_diagnosis() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    LOKI STACK - DIAGNÓSTICO COMPLETO"
    echo "============================================================================"
    echo -e "${NC}"
    
    check_installation
    check_docker
    check_containers
    check_services
    check_logs_ingestion
    check_disk_space
    check_permissions
    check_network
    
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}Diagnóstico completo finalizado!${NC}"
    echo
    echo -e "${YELLOW}Se ainda houver problemas:${NC}"
    echo "• Execute: $0 --logs (para ver logs detalhados)"
    echo "• Execute: $0 --fix (para tentar correções automáticas)"
    echo "• Execute: $0 --reset (para reiniciar serviços)"
    echo
}

# Função principal
main() {
    case "${1:-}" in
        --full)
            full_diagnosis
            ;;
        --logs)
            check_installation
            show_logs
            ;;
        --fix)
            check_installation
            fix_common_issues
            ;;
        --reset)
            check_installation
            reset_services
            ;;
        --clean)
            check_installation
            clean_and_restart
            ;;
        --help)
            show_help
            ;;
        *)
            full_diagnosis
            ;;
    esac
}

main "$@"
