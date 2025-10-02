#!/bin/bash

# ============================================================================
# GIT SETUP - CONFIGURAÇÃO INICIAL DO REPOSITÓRIO
# ============================================================================
# Script para configuração inicial do Git e GitHub
# ============================================================================

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

REPO_URL="https://github.com/severance443/New_project.git"

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
    exit 1
}

show_banner() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    GIT SETUP - CONFIGURAÇÃO INICIAL"
    echo "============================================================================"
    echo "Este script irá configurar o Git e conectar ao seu repositório GitHub"
    echo "Repositório: ${REPO_URL}"
    echo "============================================================================"
    echo -e "${NC}"
}

install_git() {
    if ! command -v git >/dev/null 2>&1; then
        log "Instalando Git..."
        sudo apt-get update
        sudo apt-get install -y git
        log "Git instalado ✓"
    else
        log "Git já está instalado ✓"
    fi
}

configure_git() {
    log "Configurando Git..."
    
    # Nome do usuário
    current_name=$(git config --global user.name 2>/dev/null || echo "")
    if [[ -z "$current_name" ]]; then
        echo -n "Digite seu nome completo: "
        read git_name
        git config --global user.name "$git_name"
        log "Nome configurado: $git_name"
    else
        log "Nome já configurado: $current_name"
    fi
    
    # Email do usuário
    current_email=$(git config --global user.email 2>/dev/null || echo "")
    if [[ -z "$current_email" ]]; then
        echo -n "Digite seu email: "
        read git_email
        git config --global user.email "$git_email"
        log "Email configurado: $git_email"
    else
        log "Email já configurado: $current_email"
    fi
    
    # Configurações adicionais
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global credential.helper store
    
    log "Git configurado ✓"
}

setup_ssh_key() {
    log "Verificando chave SSH..."
    
    if [[ ! -f ~/.ssh/id_rsa.pub ]] && [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
        warn "Nenhuma chave SSH encontrada"
        
        read -p "Deseja criar uma chave SSH? (recomendado) (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log "Gerando chave SSH..."
            
            email=$(git config --global user.email)
            ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""
            
            # Iniciar ssh-agent
            eval "$(ssh-agent -s)"
            ssh-add ~/.ssh/id_ed25519
            
            log "Chave SSH gerada ✓"
            
            echo -e "${YELLOW}"
            echo "============================================================================"
            echo "                    CONFIGURAÇÃO DA CHAVE SSH"
            echo "============================================================================"
            echo -e "${NC}"
            echo "Sua chave SSH pública:"
            echo
            cat ~/.ssh/id_ed25519.pub
            echo
            echo -e "${YELLOW}IMPORTANTE:${NC}"
            echo "1. Copie a chave SSH acima"
            echo "2. Vá para: https://github.com/settings/ssh/new"
            echo "3. Cole a chave e salve"
            echo "4. Pressione ENTER quando terminar..."
            read
        fi
    else
        log "Chave SSH já existe ✓"
    fi
}

test_github_connection() {
    log "Testando conexão com GitHub..."
    
    # Testar conexão SSH se disponível
    if [[ -f ~/.ssh/id_rsa.pub ]] || [[ -f ~/.ssh/id_ed25519.pub ]]; then
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            log "Conexão SSH com GitHub OK ✓"
            return 0
        fi
    fi
    
    # Testar conexão HTTPS
    if git ls-remote $REPO_URL >/dev/null 2>&1; then
        log "Conexão HTTPS com GitHub OK ✓"
        return 0
    fi
    
    warn "Não foi possível conectar ao GitHub"
    echo "Verifique:"
    echo "1. Sua conexão com a internet"
    echo "2. Se o repositório existe e você tem acesso"
    echo "3. Suas credenciais do GitHub"
    
    return 1
}

create_github_token_guide() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    COMO CRIAR TOKEN DO GITHUB"
    echo "============================================================================"
    echo -e "${NC}"
    echo "Se você não tem chave SSH configurada, precisará de um token:"
    echo
    echo "1. Vá para: https://github.com/settings/tokens"
    echo "2. Clique em 'Generate new token (classic)'"
    echo "3. Dê um nome para o token (ex: 'Loki Stack Project')"
    echo "4. Selecione os escopos: 'repo' (acesso completo aos repositórios)"
    echo "5. Clique em 'Generate token'"
    echo "6. COPIE o token (você não verá ele novamente!)"
    echo "7. Use o token como senha quando o Git pedir"
    echo
    echo "Usuário: seu_usuario_github"
    echo "Senha: cole_o_token_aqui"
    echo
}

main() {
    show_banner
    
    read -p "Deseja continuar com a configuração? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Configuração cancelada."
        exit 0
    fi
    
    install_git
    configure_git
    
    echo
    echo -e "${BLUE}Escolha o método de autenticação:${NC}"
    echo "1. SSH (recomendado - mais seguro)"
    echo "2. HTTPS com token"
    echo
    read -p "Escolha (1 ou 2): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            setup_ssh_key
            ;;
        2)
            create_github_token_guide
            ;;
        *)
            warn "Opção inválida. Continuando com HTTPS..."
            create_github_token_guide
            ;;
    esac
    
    test_github_connection
    
    echo -e "${GREEN}"
    echo "============================================================================"
    echo "                    CONFIGURAÇÃO CONCLUÍDA!"
    echo "============================================================================"
    echo -e "${NC}"
    echo "✅ Git configurado"
    echo "✅ Repositório: $REPO_URL"
    echo "✅ Pronto para usar o script git-push.sh"
    echo
    echo -e "${BLUE}Próximos passos:${NC}"
    echo "1. Use: ./git-push.sh para enviar arquivos"
    echo "2. Use: ./git-push.sh \"sua mensagem\" para commit personalizado"
    echo "3. Use: ./git-push.sh --help para ver todas as opções"
    echo
}

main "$@"
