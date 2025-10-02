#!/usr/bin/env python3
"""
Script para obter informações básicas de um vídeo do YouTube
"""

import urllib.request
import urllib.parse
import json
import re
import sys

def get_video_info(video_id):
    """Obtém informações básicas do vídeo do YouTube"""
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
        
        # Extrair título
        title_pattern = r'<title>([^<]+)</title>'
        title_match = re.search(title_pattern, html)
        title = title_match.group(1) if title_match else "Título não encontrado"
        
        # Extrair descrição
        desc_pattern = r'"shortDescription":"([^"]*)"'
        desc_match = re.search(desc_pattern, html)
        description = desc_match.group(1) if desc_match else "Descrição não encontrada"
        
        # Limpar caracteres de escape
        description = description.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
        
        return {
            'title': title,
            'description': description,
            'url': video_url
        }
        
    except Exception as e:
        print(f"Erro ao obter informações do vídeo: {e}")
        return None

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

def main():
    if len(sys.argv) != 2:
        print("Uso: python3 youtube_info.py <URL_DO_VIDEO>")
        sys.exit(1)
    
    video_url = sys.argv[1]
    video_id = get_video_id(video_url)
    
    if not video_id:
        print("Não foi possível extrair o ID do vídeo da URL fornecida")
        sys.exit(1)
    
    print(f"ID do vídeo: {video_id}")
    print("Obtendo informações do vídeo...")
    
    info = get_video_info(video_id)
    
    if info:
        print(f"\nTítulo: {info['title']}")
        print(f"\nDescrição:\n{info['description']}")
        
        # Salvar informações em arquivo
        with open(f'/home/sev/new_project/video_info_{video_id}.txt', 'w', encoding='utf-8') as f:
            f.write(f"Título: {info['title']}\n\n")
            f.write(f"URL: {info['url']}\n\n")
            f.write(f"Descrição:\n{info['description']}\n")
        
        print(f"\nInformações salvas em: video_info_{video_id}.txt")
    else:
        print("Não foi possível obter informações do vídeo")

if __name__ == "__main__":
    main()

