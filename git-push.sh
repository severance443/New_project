#!/bin/bash

# ============================================================================
# GIT PUSH AUTOMÁTICO - LOKI STACK PROJECT
# ============================================================================
# Script para automatizar commits e push para GitHub
# Uso: ./git-push.sh [mensagem do commit]
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
REPO_URL="https://github.com/severance443/New_project.git"
BRANCH="main"

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

# Função para mostrar banner
show_banner() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    GIT PUSH AUTOMÁTICO - LOKI STACK"
    echo "============================================================================"
    echo "Repositório: ${REPO_URL}"
    echo "Branch: ${BRANCH}"
    echo "============================================================================"
    echo -e "${NC}"
}

# Função para verificar se git está instalado
check_git() {
    if ! command -v git >/dev/null 2>&1; then
        error "Git não está instalado. Instale com: sudo apt-get install git"
    fi
}

# Função para configurar git se necessário
setup_git() {
    log "Verificando configuração do Git..."
    
    # Verificar se nome e email estão configurados
    if ! git config --global user.name >/dev/null 2>&1; then
        warn "Nome do usuário Git não configurado"
        read -p "Digite seu nome para o Git: " git_name
        git config --global user.name "$git_name"
        log "Nome configurado: $git_name"
    fi
    
    if ! git config --global user.email >/dev/null 2>&1; then
        warn "Email do usuário Git não configurado"
        read -p "Digite seu email para o Git: " git_email
        git config --global user.email "$git_email"
        log "Email configurado: $git_email"
    fi
    
    info "Git configurado ✓"
}

# Função para inicializar repositório se necessário
init_repo() {
    if [[ ! -d ".git" ]]; then
        log "Inicializando repositório Git..."
        git init
        git branch -M $BRANCH
        git remote add origin $REPO_URL
        log "Repositório inicializado ✓"
    else
        log "Repositório Git já existe ✓"
        
        # Verificar se remote origin existe
        if ! git remote get-url origin >/dev/null 2>&1; then
            log "Adicionando remote origin..."
            git remote add origin $REPO_URL
        else
            # Verificar se URL está correta
            current_url=$(git remote get-url origin)
            if [[ "$current_url" != "$REPO_URL" ]]; then
                log "Atualizando URL do remote origin..."
                git remote set-url origin $REPO_URL
            fi
        fi
    fi
}

# Função para criar .gitignore se não existir
create_gitignore() {
    if [[ ! -f ".gitignore" ]]; then
        log "Criando .gitignore..."
        cat > .gitignore << 'EOF'
# Logs
*.log
logs/
*.log.*

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Temporary files
*.tmp
*.temp
.cache/

# Docker volumes data (manter estrutura, não dados)
**/data/loki/*
**/data/grafana/*
!**/data/.gitkeep

# Certificates and keys
**/certificates/*
!**/certificates/.gitkeep
*.key
*.crt
*.pem
acme.json

# Environment files
.env
.env.local
.env.*.local

# Backup files
*.backup
*.bak
*~

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Sensitive information
secret_key
postgres_password
*.secret
EOF
        log ".gitignore criado ✓"
    fi
}

# Função para criar estrutura de diretórios vazios
create_placeholder_files() {
    log "Criando arquivos placeholder para diretórios vazios..."
    
    # Criar .gitkeep em diretórios que devem existir mas podem estar vazios
    directories=(
        "obsidian-vault/Grafana-Loki-Guide/Installation"
        "obsidian-vault/Grafana-Loki-Guide/Configuration"
        "obsidian-vault/Grafana-Loki-Guide/Docker-Logs"
        "obsidian-vault/Grafana-Loki-Guide/Server-Logs"
        "obsidian-vault/Grafana-Loki-Guide/Security"
    )
    
    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]] && [[ ! -f "$dir/.gitkeep" ]]; then
            touch "$dir/.gitkeep"
        fi
    done
}

# Função para verificar status do repositório
check_repo_status() {
    log "Verificando status do repositório..."
    
    # Verificar se há mudanças
    if git diff --quiet && git diff --staged --quiet; then
        warn "Nenhuma mudança detectada para commit"
        
        # Verificar se há commits não enviados
        if git log --oneline origin/$BRANCH..$BRANCH 2>/dev/null | grep -q .; then
            info "Há commits locais não enviados"
            return 0
        else
            info "Repositório está atualizado"
            return 1
        fi
    fi
    
    # Mostrar status
    echo -e "${BLUE}Status do repositório:${NC}"
    git status --short
    echo
    
    return 0
}

# Função para fazer commit e push
commit_and_push() {
    local commit_message="$1"
    
    # Se não foi fornecida mensagem, usar padrão
    if [[ -z "$commit_message" ]]; then
        commit_message="Update Loki Stack - $(date +'%Y-%m-%d %H:%M:%S')"
    fi
    
    log "Preparando commit..."
    
    # Adicionar todos os arquivos
    git add .
    
    # Verificar se há algo para commit
    if git diff --staged --quiet; then
        warn "Nenhuma mudança para commit"
        return 1
    fi
    
    # Mostrar arquivos que serão commitados
    echo -e "${BLUE}Arquivos que serão commitados:${NC}"
    git diff --staged --name-status
    echo
    
    # Fazer commit
    log "Fazendo commit: $commit_message"
    git commit -m "$commit_message"
    
    # Push para o repositório
    log "Enviando para GitHub..."
    
    # Verificar se é o primeiro push
    if ! git ls-remote --heads origin $BRANCH | grep -q $BRANCH; then
        info "Primeiro push - criando branch $BRANCH"
        git push -u origin $BRANCH
    else
        git push origin $BRANCH
    fi
    
    log "Push realizado com sucesso ✓"
    
    return 0
}

# Função para mostrar informações do repositório
show_repo_info() {
    echo -e "${BLUE}Informações do Repositório:${NC}"
    echo "• URL: $REPO_URL"
    echo "• Branch: $BRANCH"
    echo "• Último commit: $(git log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || echo 'Nenhum commit ainda')"
    echo "• Status: $(git status --porcelain | wc -l) arquivos modificados"
    echo
}

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [mensagem do commit]"
    echo
    echo "Exemplos:"
    echo "  $0                           # Commit com mensagem automática"
    echo "  $0 \"Added new feature\"       # Commit com mensagem personalizada"
    echo "  $0 \"Fixed bug in deploy\"     # Commit com descrição específica"
    echo
    echo "Opções especiais:"
    echo "  --status    Mostrar apenas o status do repositório"
    echo "  --info      Mostrar informações do repositório"
    echo "  --help      Mostrar esta ajuda"
    echo
}

# Função para verificar conectividade com GitHub
check_github_connectivity() {
    log "Verificando conectividade com GitHub..."
    
    if ! ping -c 1 github.com >/dev/null 2>&1; then
        error "Não foi possível conectar ao GitHub. Verifique sua conexão com a internet."
    fi
    
    # Testar acesso ao repositório
    if ! git ls-remote $REPO_URL >/dev/null 2>&1; then
        warn "Não foi possível acessar o repositório. Pode ser necessário autenticação."
        info "Configure suas credenciais do GitHub:"
        info "1. Token de acesso: git config --global credential.helper store"
        info "2. SSH: Configure chaves SSH em ~/.ssh/"
    fi
}

# Função principal
main() {
    show_banner
    
    # Verificar argumentos especiais
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --status)
            check_repo_status
            exit 0
            ;;
        --info)
            show_repo_info
            exit 0
            ;;
    esac
    
    # Verificações iniciais
    check_git
    setup_git
    check_github_connectivity
    
    # Configurar repositório
    init_repo
    create_gitignore
    create_placeholder_files
    
    # Verificar se há mudanças
    if ! check_repo_status; then
        info "Nada para fazer. Repositório já está atualizado."
        exit 0
    fi
    
    # Mostrar informações
    show_repo_info
    
    # Confirmar com usuário
    read -p "Deseja continuar com o commit e push? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Operação cancelada pelo usuário."
        exit 0
    fi
    
    # Fazer commit e push
    if commit_and_push "$1"; then
        echo -e "${GREEN}"
        echo "============================================================================"
        echo "                    PUSH REALIZADO COM SUCESSO!"
        echo "============================================================================"
        echo -e "${NC}"
        echo "🌐 Repositório: $REPO_URL"
        echo "📝 Último commit: $(git log -1 --pretty=format:'%s')"
        echo "🕒 Data: $(date)"
        echo
        echo -e "${GREEN}✅ Seus arquivos foram enviados para o GitHub!${NC}"
    else
        error "Falha ao realizar push"
    fi
}

# Executar função principal
main "$@"
