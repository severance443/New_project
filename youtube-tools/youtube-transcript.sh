#!/bin/bash

# ============================================================================
# YOUTUBE TRANSCRIPT EXTRACTOR
# ============================================================================
# Script principal para extrair transcripts de vídeos do YouTube
# Uso: ./youtube-transcript.sh [URL_DO_VIDEO] [opções]
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configurações
OUTPUT_DIR="./transcripts"
TEMP_DIR="/tmp/youtube-transcript"

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

success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# Função para mostrar banner
show_banner() {
    echo -e "${BLUE}"
    echo "============================================================================"
    echo "                    YOUTUBE TRANSCRIPT EXTRACTOR"
    echo "============================================================================"
    echo "Extrai transcripts de vídeos do YouTube para criar documentação"
    echo "============================================================================"
    echo -e "${NC}"
}

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [URL_DO_VIDEO] [opções]"
    echo
    echo "Opções:"
    echo "  --summary          Gerar resumo do conteúdo"
    echo "  --timestamps       Incluir timestamps no output"
    echo "  --format=FORMAT    Formato de saída (txt, md, json)"
    echo "  --output=DIR       Diretório de saída (padrão: ./transcripts)"
    echo "  --fallback         Usar métodos alternativos se API falhar"
    echo "  --info-only        Extrair apenas informações do vídeo"
    echo "  --test             Testar instalação"
    echo "  --help             Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 \"https://www.youtube.com/watch?v=VIDEO_ID\""
    echo "  $0 \"https://youtu.be/VIDEO_ID\" --summary --format=md"
    echo "  $0 \"https://www.youtube.com/watch?v=VIDEO_ID\" --timestamps --output=./docs"
    echo
}

# Função para verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Verificar Python
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python3 não encontrado. Instale com: sudo apt-get install python3"
    fi
    
    # Verificar bibliotecas Python necessárias
    python3 -c "import requests, json, re" 2>/dev/null || {
        warn "Bibliotecas Python não encontradas. Instalando..."
        pip3 install requests beautifulsoup4 || {
            error "Falha ao instalar dependências. Execute: pip3 install requests beautifulsoup4"
        }
    }
    
    # Verificar ferramentas opcionais
    if command -v jq >/dev/null 2>&1; then
        info "jq encontrado - processamento JSON disponível ✓"
    else
        warn "jq não encontrado - instale para melhor processamento JSON: sudo apt-get install jq"
    fi
    
    log "Dependências verificadas ✓"
}

# Função para extrair ID do vídeo
extract_video_id() {
    local url="$1"
    local video_id=""
    
    # Padrões de URL do YouTube
    if [[ "$url" =~ youtube\.com/watch\?v=([a-zA-Z0-9_-]+) ]]; then
        video_id="${BASH_REMATCH[1]}"
    elif [[ "$url" =~ youtu\.be/([a-zA-Z0-9_-]+) ]]; then
        video_id="${BASH_REMATCH[1]}"
    elif [[ "$url" =~ youtube\.com/embed/([a-zA-Z0-9_-]+) ]]; then
        video_id="${BASH_REMATCH[1]}"
    elif [[ "$url" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
        video_id="$url"
    else
        error "URL do YouTube inválida: $url"
    fi
    
    echo "$video_id"
}

# Função para obter informações do vídeo
get_video_info() {
    local video_id="$1"
    local info_file="$TEMP_DIR/video_info_$video_id.json"
    
    log "Obtendo informações do vídeo: $video_id"
    
    # Usar script Python para obter informações
    python3 - << EOF > "$info_file"
import requests
import json
import re
import sys

def get_video_info(video_id):
    try:
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        response = requests.get(video_url, headers=headers)
        html = response.text
        
        # Extrair título
        title_match = re.search(r'<title>([^<]+)</title>', html)
        title = title_match.group(1) if title_match else "Título não encontrado"
        title = title.replace(' - YouTube', '')
        
        # Extrair descrição
        desc_match = re.search(r'"shortDescription":"([^"]*)"', html)
        description = desc_match.group(1) if desc_match else "Descrição não encontrada"
        description = description.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
        
        # Extrair duração
        duration_match = re.search(r'"lengthSeconds":"(\d+)"', html)
        duration = int(duration_match.group(1)) if duration_match else 0
        
        # Extrair canal
        channel_match = re.search(r'"author":"([^"]+)"', html)
        channel = channel_match.group(1) if channel_match else "Canal não encontrado"
        
        return {
            'video_id': video_id,
            'title': title,
            'description': description,
            'duration': duration,
            'channel': channel,
            'url': video_url
        }
        
    except Exception as e:
        return {'error': str(e)}

info = get_video_info("$video_id")
print(json.dumps(info, indent=2, ensure_ascii=False))
EOF
    
    if [[ -f "$info_file" ]]; then
        success "Informações do vídeo obtidas ✓"
        return 0
    else
        error "Falha ao obter informações do vídeo"
        return 1
    fi
}

# Função para tentar extrair transcript
extract_transcript() {
    local video_id="$1"
    local transcript_file="$TEMP_DIR/transcript_$video_id.txt"
    
    log "Tentando extrair transcript: $video_id"
    
    # Método 1: YouTube Transcript API (se disponível)
    if command -v youtube-transcript-api >/dev/null 2>&1; then
        info "Tentando YouTube Transcript API..."
        if youtube-transcript-api "$video_id" > "$transcript_file" 2>/dev/null; then
            success "Transcript extraído via API ✓"
            return 0
        fi
    fi
    
    # Método 2: Web scraping
    info "Tentando extração via web scraping..."
    python3 - << EOF > "$transcript_file"
import requests
import re
import json

def extract_captions(video_id):
    try:
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(video_url, headers=headers)
        html = response.text
        
        # Procurar por dados de legendas
        caption_pattern = r'"captions":\{"playerCaptionsTracklistRenderer":\{"captionTracks":\[([^\]]+)\]'
        match = re.search(caption_pattern, html)
        
        if match:
            captions_data = match.group(1)
            url_pattern = r'"baseUrl":"([^"]+)"'
            url_match = re.search(url_pattern, captions_data)
            
            if url_match:
                transcript_url = url_match.group(1).replace('\\u0026', '&')
                
                # Obter transcript
                response = requests.get(transcript_url, headers=headers)
                transcript_xml = response.text
                
                # Extrair texto do XML
                text_pattern = r'<text[^>]*>([^<]+)</text>'
                texts = re.findall(text_pattern, transcript_xml)
                
                # Limpar e juntar texto
                transcript = ' '.join([text.strip() for text in texts if text.strip()])
                
                if transcript:
                    print(transcript)
                    return True
        
        return False
        
    except Exception as e:
        print(f"Erro: {e}", file=sys.stderr)
        return False

import sys
if not extract_captions("$video_id"):
    sys.exit(1)
EOF
    
    if [[ -s "$transcript_file" ]]; then
        success "Transcript extraído via web scraping ✓"
        return 0
    else
        warn "Não foi possível extrair transcript automaticamente"
        return 1
    fi
}

# Função para processar transcript
process_transcript() {
    local video_id="$1"
    local format="$2"
    local include_timestamps="$3"
    local generate_summary="$4"
    
    local info_file="$TEMP_DIR/video_info_$video_id.json"
    local transcript_file="$TEMP_DIR/transcript_$video_id.txt"
    local output_file="$OUTPUT_DIR/${video_id}_transcript.$format"
    
    log "Processando transcript..."
    
    # Criar diretório de saída
    mkdir -p "$OUTPUT_DIR"
    
    # Ler informações do vídeo
    local title="Título não disponível"
    local channel="Canal não disponível"
    local description="Descrição não disponível"
    
    if [[ -f "$info_file" ]]; then
        if command -v jq >/dev/null 2>&1; then
            title=$(jq -r '.title // "Título não disponível"' "$info_file")
            channel=$(jq -r '.channel // "Canal não disponível"' "$info_file")
            description=$(jq -r '.description // "Descrição não disponível"' "$info_file")
        fi
    fi
    
    # Processar baseado no formato
    case "$format" in
        "md"|"markdown")
            cat > "$output_file" << EOF
# $title

**Canal:** $channel  
**Vídeo ID:** $video_id  
**URL:** https://www.youtube.com/watch?v=$video_id  
**Data de extração:** $(date)

## Descrição

$description

## Transcript

EOF
            if [[ -f "$transcript_file" ]]; then
                cat "$transcript_file" >> "$output_file"
            else
                echo "Transcript não disponível" >> "$output_file"
            fi
            ;;
            
        "json")
            cat > "$output_file" << EOF
{
  "video_id": "$video_id",
  "title": "$title",
  "channel": "$channel",
  "url": "https://www.youtube.com/watch?v=$video_id",
  "extraction_date": "$(date -Iseconds)",
  "description": "$description",
  "transcript": "$(cat "$transcript_file" 2>/dev/null | sed 's/"/\\"/g' | tr '\n' ' ')"
}
EOF
            ;;
            
        *)  # txt (padrão)
            cat > "$output_file" << EOF
Título: $title
Canal: $channel
Vídeo ID: $video_id
URL: https://www.youtube.com/watch?v=$video_id
Data de extração: $(date)

Descrição:
$description

Transcript:
EOF
            if [[ -f "$transcript_file" ]]; then
                cat "$transcript_file" >> "$output_file"
            else
                echo "Transcript não disponível" >> "$output_file"
            fi
            ;;
    esac
    
    success "Transcript processado: $output_file"
    echo "$output_file"
}

# Função para gerar resumo
generate_summary() {
    local transcript_file="$1"
    
    if [[ ! -f "$transcript_file" ]]; then
        warn "Arquivo de transcript não encontrado para resumo"
        return 1
    fi
    
    log "Gerando resumo..."
    
    # Resumo simples baseado em tamanho
    local word_count=$(wc -w < "$transcript_file")
    local char_count=$(wc -c < "$transcript_file")
    
    echo
    echo -e "${BLUE}=== RESUMO ===${NC}"
    echo "• Palavras: $word_count"
    echo "• Caracteres: $char_count"
    echo "• Tempo estimado de leitura: $((word_count / 200)) minutos"
    
    # Extrair primeiras e últimas frases
    echo
    echo -e "${BLUE}=== INÍCIO ===${NC}"
    head -c 300 "$transcript_file" | tr '\n' ' '
    echo "..."
    
    echo
    echo -e "${BLUE}=== FINAL ===${NC}"
    tail -c 300 "$transcript_file" | tr '\n' ' '
    echo
}

# Função para testar instalação
test_installation() {
    log "Testando instalação..."
    
    check_dependencies
    
    # Testar com vídeo de exemplo
    local test_video="dQw4w9WgXcQ"  # Never Gonna Give You Up
    info "Testando com vídeo de exemplo: $test_video"
    
    mkdir -p "$TEMP_DIR"
    
    if get_video_info "$test_video"; then
        success "Teste de extração de informações: OK ✓"
    else
        error "Teste de extração de informações: FALHOU ❌"
    fi
    
    success "Instalação testada com sucesso! ✓"
}

# Função principal
main() {
    show_banner
    
    # Variáveis padrão
    local video_url=""
    local format="txt"
    local include_timestamps=false
    local generate_summary_flag=false
    local fallback=false
    local info_only=false
    
    # Processar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --test)
                test_installation
                exit 0
                ;;
            --summary)
                generate_summary_flag=true
                shift
                ;;
            --timestamps)
                include_timestamps=true
                shift
                ;;
            --format=*)
                format="${1#*=}"
                shift
                ;;
            --output=*)
                OUTPUT_DIR="${1#*=}"
                shift
                ;;
            --fallback)
                fallback=true
                shift
                ;;
            --info-only)
                info_only=true
                shift
                ;;
            -*)
                error "Opção desconhecida: $1"
                ;;
            *)
                if [[ -z "$video_url" ]]; then
                    video_url="$1"
                else
                    error "Múltiplas URLs fornecidas. Use apenas uma."
                fi
                shift
                ;;
        esac
    done
    
    # Verificar se URL foi fornecida
    if [[ -z "$video_url" ]] && [[ "$1" != "--test" ]]; then
        error "URL do vídeo é obrigatória. Use --help para ver opções."
    fi
    
    # Verificar dependências
    check_dependencies
    
    # Criar diretório temporário
    mkdir -p "$TEMP_DIR"
    
    # Extrair ID do vídeo
    local video_id
    video_id=$(extract_video_id "$video_url")
    info "ID do vídeo: $video_id"
    
    # Obter informações do vídeo
    if ! get_video_info "$video_id"; then
        error "Falha ao obter informações do vídeo"
    fi
    
    # Se apenas informações foram solicitadas
    if [[ "$info_only" == true ]]; then
        local info_file="$TEMP_DIR/video_info_$video_id.json"
        if [[ -f "$info_file" ]]; then
            cat "$info_file"
        fi
        exit 0
    fi
    
    # Extrair transcript
    local transcript_available=false
    if extract_transcript "$video_id"; then
        transcript_available=true
    elif [[ "$fallback" == true ]]; then
        warn "Transcript não disponível via métodos automáticos"
        info "Considere usar ferramentas online como:"
        info "• https://tactiq.io/pt-br/ferramentas/transcricao-do-youtube"
        info "• https://krisp.ai/pt-pt/youtube-transcript/"
    else
        warn "Transcript não disponível. Use --fallback para ver alternativas."
    fi
    
    # Processar e salvar resultado
    local output_file
    output_file=$(process_transcript "$video_id" "$format" "$include_timestamps" "$generate_summary_flag")
    
    # Gerar resumo se solicitado
    if [[ "$generate_summary_flag" == true ]] && [[ "$transcript_available" == true ]]; then
        generate_summary "$TEMP_DIR/transcript_$video_id.txt"
    fi
    
    # Limpar arquivos temporários
    rm -rf "$TEMP_DIR"
    
    echo
    success "Processamento concluído!"
    info "Arquivo salvo em: $output_file"
    
    if [[ "$transcript_available" == true ]]; then
        info "Transcript extraído com sucesso ✓"
    else
        warn "Transcript não disponível - apenas informações do vídeo foram salvas"
    fi
}

# Executar função principal
main "$@"
