#!/usr/bin/env python3
"""
Script para extrair transcript de vídeo do YouTube
"""

import urllib.request
import urllib.parse
import json
import re
import sys

def get_video_id(url):
    """Extrai o ID do vídeo da URL do YouTube"""
    patterns = [
        r'(?:v=|\/)([0-9A-Za-z_-]{11}).*',
        r'(?:embed\/)([0-9A-Za-z_-]{11})',
        r'(?:watch\?v=)([0-9A-Za-z_-]{11})'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None

def get_transcript_from_youtube(video_id):
    """Tenta obter transcript do YouTube usando a API interna"""
    try:
        # URL para obter informações do vídeo
        video_url = f"https://www.youtube.com/watch?v={video_id}"
        
        # Headers para simular um navegador
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        # Fazer requisição para a página do vídeo
        req = urllib.request.Request(video_url, headers=headers)
        response = urllib.request.urlopen(req)
        html = response.read().decode('utf-8')
        
        # Procurar por dados de transcript na página
        transcript_pattern = r'"captions":\{"playerCaptionsTracklistRenderer":\{"captionTracks":\[([^\]]+)\]'
        match = re.search(transcript_pattern, html)
        
        if match:
            captions_data = match.group(1)
            # Procurar pela URL do transcript
            url_pattern = r'"baseUrl":"([^"]+)"'
            url_match = re.search(url_pattern, captions_data)
            
            if url_match:
                transcript_url = url_match.group(1).replace('\\u0026', '&')
                
                # Fazer requisição para obter o transcript
                req = urllib.request.Request(transcript_url, headers=headers)
                response = urllib.request.urlopen(req)
                transcript_xml = response.read().decode('utf-8')
                
                # Extrair texto do XML
                text_pattern = r'<text[^>]*>([^<]+)</text>'
                texts = re.findall(text_pattern, transcript_xml)
                
                # Limpar e juntar o texto
                transcript = ' '.join([text.strip() for text in texts if text.strip()])
                return transcript
        
        return None
        
    except Exception as e:
        print(f"Erro ao obter transcript: {e}")
        return None

def main():
    if len(sys.argv) != 2:
        print("Uso: python3 get_youtube_transcript.py <URL_DO_VIDEO>")
        sys.exit(1)
    
    video_url = sys.argv[1]
    video_id = get_video_id(video_url)
    
    if not video_id:
        print("Não foi possível extrair o ID do vídeo da URL fornecida")
        sys.exit(1)
    
    print(f"ID do vídeo: {video_id}")
    print("Obtendo transcript...")
    
    transcript = get_transcript_from_youtube(video_id)
    
    if transcript:
        # Salvar transcript em arquivo
        with open(f'/home/sev/new_project/transcript_{video_id}.txt', 'w', encoding='utf-8') as f:
            f.write(transcript)
        print(f"Transcript salvo em: transcript_{video_id}.txt")
        print("\nPrimeiros 500 caracteres do transcript:")
        print(transcript[:500] + "...")
    else:
        print("Não foi possível obter o transcript do vídeo")
        print("Isso pode acontecer se:")
        print("- O vídeo não tem legendas/transcript disponível")
        print("- O vídeo é privado ou restrito")
        print("- Houve um problema de conectividade")

if __name__ == "__main__":
    main()

