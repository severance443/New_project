# 📤 Guia Completo - Envio para GitHub

Este guia explica como usar os scripts para enviar seus arquivos para o repositório GitHub [https://github.com/severance443/New_project.git](https://github.com/severance443/New_project.git).

## 🚀 Setup Inicial (Apenas uma vez)

### 1. Configurar Git e GitHub
```bash
./git-setup.sh
```

Este script irá:
- ✅ Instalar Git (se necessário)
- ✅ Configurar seu nome e email
- ✅ Gerar chave SSH (recomendado) ou configurar token
- ✅ Testar conexão com GitHub

### 2. Escolher Método de Autenticação

#### Opção A: SSH (Recomendado - Mais Seguro)
1. O script gerará uma chave SSH automaticamente
2. Copie a chave pública mostrada
3. Vá para: https://github.com/settings/ssh/new
4. Cole a chave e salve

#### Opção B: Token HTTPS
1. Vá para: https://github.com/settings/tokens
2. Clique em "Generate new token (classic)"
3. Selecione escopo "repo"
4. Copie o token gerado
5. Use como senha quando solicitado

## 📤 Enviando Arquivos

### Uso Básico
```bash
# Envio simples (mensagem automática)
./git-push.sh

# Envio com mensagem personalizada
./git-push.sh "Added README.md"
./git-push.sh "Fixed deployment bug"
./git-push.sh "Updated Loki configuration"
```

### Comandos Úteis
```bash
# Ver status do repositório
./git-push.sh --status

# Ver informações do repositório
./git-push.sh --info

# Ver ajuda
./git-push.sh --help
```

## 📋 Exemplos Práticos

### Primeiro Envio
```bash
# 1. Configurar (apenas uma vez)
./git-setup.sh

# 2. Enviar todos os arquivos
./git-push.sh "Initial commit - Loki Stack project"
```

### Atualizações Regulares
```bash
# Depois de modificar arquivos
./git-push.sh "Updated deployment script"

# Depois de adicionar novos recursos
./git-push.sh "Added monitoring dashboard"

# Correções de bugs
./git-push.sh "Fixed Promtail configuration"
```

### Fluxo de Trabalho Típico
```bash
# 1. Fazer mudanças nos arquivos
nano deploy-loki-stack.sh

# 2. Testar mudanças
./deploy-loki-stack.sh

# 3. Enviar para GitHub
./git-push.sh "Improved deployment script with better error handling"
```

## 🔧 Recursos dos Scripts

### git-setup.sh
- ✅ Instalação automática do Git
- ✅ Configuração de nome e email
- ✅ Geração de chaves SSH
- ✅ Teste de conectividade
- ✅ Guia para tokens GitHub

### git-push.sh
- ✅ Commit automático de todas as mudanças
- ✅ Push para GitHub
- ✅ Mensagens personalizadas
- ✅ Verificação de status
- ✅ Criação automática de .gitignore
- ✅ Confirmação antes do envio

## 📁 Arquivos que Serão Enviados

### ✅ Incluídos
- Scripts de deploy (`*.sh`)
- Documentação (`*.md`)
- Guias do Obsidian (`obsidian-vault/`)
- Configurações de exemplo
- Estrutura de diretórios

### ❌ Excluídos (via .gitignore)
- Dados dos volumes Docker (`data/loki/*`, `data/grafana/*`)
- Logs (`*.log`, `logs/`)
- Certificados SSL (`*.key`, `*.crt`, `acme.json`)
- Arquivos temporários (`*.tmp`, `.cache/`)
- Credenciais (`.env`, `secret_key`, etc.)

## 🔐 Segurança

### Informações Sensíveis
O script automaticamente **NÃO** envia:
- Senhas ou tokens
- Certificados SSL
- Dados de logs
- Arquivos de configuração com credenciais

### Boas Práticas
- ✅ Use chaves SSH quando possível
- ✅ Mantenha tokens seguros
- ✅ Não commite credenciais
- ✅ Use mensagens descritivas nos commits

## 🚨 Troubleshooting

### Erro: "Permission denied (publickey)"
```bash
# Verificar se chave SSH está carregada
ssh-add -l

# Se não estiver, adicionar
ssh-add ~/.ssh/id_ed25519

# Testar conexão
ssh -T git@github.com
```

### Erro: "Authentication failed"
```bash
# Para HTTPS, verificar credenciais
git config --global credential.helper store

# Fazer push manualmente para inserir credenciais
git push origin main
```

### Erro: "Repository not found"
```bash
# Verificar URL do repositório
git remote -v

# Corrigir se necessário
git remote set-url origin https://github.com/severance443/New_project.git
```

### Erro: "Nothing to commit"
```bash
# Verificar status
./git-push.sh --status

# Ver mudanças
git status
```

## 📊 Monitoramento

### Verificar Último Envio
```bash
# Ver informações do repositório
./git-push.sh --info

# Ver histórico de commits
git log --oneline -10
```

### Status do Repositório
```bash
# Status detalhado
./git-push.sh --status

# Ver diferenças
git diff
```

## 🎯 Fluxo Completo de Exemplo

```bash
# === SETUP INICIAL (apenas uma vez) ===
./git-setup.sh

# === DESENVOLVIMENTO ===
# Fazer mudanças nos arquivos...
nano README.md

# === TESTE ===
./quick-start.sh

# === ENVIO PARA GITHUB ===
./git-push.sh "Updated README with new instructions"

# === VERIFICAÇÃO ===
./git-push.sh --info
```

## 🌐 Links Úteis

- **Repositório**: https://github.com/severance443/New_project.git
- **SSH Keys**: https://github.com/settings/ssh/new
- **Tokens**: https://github.com/settings/tokens
- **Documentação Git**: https://git-scm.com/docs

---

**✅ Com estes scripts, enviar para GitHub é simples e automático!**

Use `./git-push.sh "sua mensagem"` sempre que quiser atualizar o repositório.
