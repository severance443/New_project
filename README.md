# 🚀 Grafana Loki Stack - Deploy Automático

Sistema completo de logs centralizados baseado no **Grafana Loki**, com deploy automático e configuração completa.

## 📁 Estrutura do Projeto

```
📦 new_project/
├── 📂 scripts/                    # Scripts de automação
│   ├── 🚀 deploy-loki-stack.sh   # Deploy completo do Loki Stack
│   ├── ⚡ quick-start.sh         # Verificação rápida
│   ├── 🔧 troubleshoot.sh        # Diagnóstico e correção
│   ├── 📤 git-push.sh            # Envio automático para GitHub
│   └── ⚙️ git-setup.sh           # Configuração inicial do Git
├── 📂 docs/                       # Documentação completa
│   ├── 📖 GITHUB-GUIDE.md        # Guia de uso do GitHub
│   └── 📚 obsidian-vault/        # Guias detalhados do Loki
├── 📂 youtube-tools/              # Ferramentas do YouTube (projeto separado)
├── 📂 loki-stack/                 # Dados do Loki (criado após deploy)
└── 📄 README.md                   # Este arquivo
```

## 🎯 O que será instalado

- **🔍 Grafana Loki** - Agregação e armazenamento de logs
- **📝 Promtail** - Coleta de logs do sistema e Docker
- **📊 Grafana** - Interface de visualização e dashboards
- **🔀 Traefik** - Reverse proxy com SSL automático
- **🔔 Alertas** - Regras de alerta pré-configuradas
- **📈 Dashboards** - Painéis prontos para monitoramento

## ⚡ Quick Start

### 1. Deploy Automático do Loki Stack

```bash
# Deploy completo
./scripts/deploy-loki-stack.sh
```

### 2. Verificar Instalação

```bash
# Verificação rápida
./scripts/quick-start.sh
```

### 3. Acessar Interfaces

- **Grafana**: https://grafana.localhost (admin/admin123)
- **Loki API**: https://loki.localhost
- **Traefik Dashboard**: https://traefik.localhost (admin/admin123)

## 🛠️ Scripts Disponíveis

### 🚀 Deploy e Gerenciamento
```bash
./scripts/deploy-loki-stack.sh    # Instalação completa automática
./scripts/quick-start.sh          # Verificação rápida pós-instalação
./scripts/troubleshoot.sh         # Diagnóstico completo
./scripts/troubleshoot.sh --logs  # Ver logs dos serviços
./scripts/troubleshoot.sh --fix   # Corrigir problemas comuns
```

### 📤 Git e GitHub
```bash
./scripts/git-setup.sh            # Configuração inicial (apenas uma vez)
./scripts/git-push.sh             # Envio automático para GitHub
./scripts/git-push.sh "mensagem"  # Envio com mensagem personalizada
./scripts/git-push.sh --status    # Ver status do repositório
```

### 🎬 YouTube Tools
```bash
cd youtube-tools/
./youtube-transcript.sh           # Extrair transcripts de vídeos
```

## 📊 Primeiros Passos no Grafana

### 1. Login
- URL: https://grafana.localhost
- Usuário: `admin`
- Senha: `admin123`

### 2. Queries de Exemplo

```logql
# Todos os logs
{job=~".+"}

# Logs de erro
{job=~".+"} |~ "(?i)(error|fail|exception)"

# Logs do sistema
{job="syslog"}

# Logs de autenticação
{job="auth"}

# Logs do Docker
{job="docker"}

# Filtrar por serviço específico
{job="docker", service="nginx"}

# Logs das últimas 5 minutos com nível ERROR
{level="error"} [5m]
```

### 3. Dashboards Incluídos

- **Loki Logs Dashboard** - Visão geral dos logs
- **System Logs** - Logs do sistema Linux
- **Docker Logs** - Logs dos containers
- **Security Dashboard** - Monitoramento de segurança

## 📤 Envio para GitHub

### Configuração Inicial (apenas uma vez)
```bash
./scripts/git-setup.sh    # Configurar Git e GitHub
```

### Enviar Arquivos para GitHub
```bash
# Envio simples com mensagem automática
./scripts/git-push.sh

# Envio com mensagem personalizada
./scripts/git-push.sh "Added new feature"
./scripts/git-push.sh "Fixed deployment script"
./scripts/git-push.sh "Updated documentation"

# Ver status do repositório
./scripts/git-push.sh --status

# Ver informações do repositório
./scripts/git-push.sh --info
```

## 🔧 Configuração Avançada

### Gerenciamento após Deploy
```bash
cd ~/loki-stack

# Monitoramento
./scripts/monitor.sh      # Status geral do sistema
./scripts/logs.sh         # Ver logs (todos ou específico)
./scripts/backup.sh       # Criar backup

# Controle de serviços
docker-compose ps         # Status dos containers
docker-compose stop       # Parar serviços
docker-compose start      # Iniciar serviços
docker-compose restart    # Reiniciar serviços
```

### Personalização

#### Adicionar Logs Personalizados
```bash
# Adicionar arquivos de log em ~/loki-stack/logs/
echo "$(date) INFO Minha aplicação iniciada" >> ~/loki-stack/logs/app.log
```

#### Modificar Configurações
```bash
# Editar configuração do Loki
nano ~/loki-stack/config/loki/loki-config.yml

# Editar configuração do Promtail
nano ~/loki-stack/config/promtail/promtail-config.yml

# Aplicar mudanças
cd ~/loki-stack
docker-compose restart
```

## 🔐 Segurança

### Configuração Atual
- **HTTPS** com certificados auto-assinados
- **Autenticação HTTP básica** no Traefik
- **Headers de segurança** configurados
- **Rate limiting** ativo

### Para Produção
1. **Alterar senhas padrão**
2. **Configurar domínios reais**
3. **Usar certificados válidos**
4. **Configurar firewall**
5. **Implementar backup automatizado**

## 🚨 Troubleshooting

### Problemas Comuns

#### Containers não iniciam
```bash
./scripts/troubleshoot.sh --fix
```

#### Logs não aparecem
```bash
# Verificar permissões
sudo usermod -a -G adm $USER
sudo usermod -a -G syslog $USER

# Reiniciar
./scripts/troubleshoot.sh --reset
```

#### Erro de certificado SSL
```bash
# Aceitar certificado auto-assinado no navegador
# Ou configurar certificados válidos para produção
```

#### Sem espaço em disco
```bash
# Verificar uso
df -h ~/loki-stack/data/

# Limpar dados antigos
./scripts/troubleshoot.sh --clean
```

### Logs de Debug
```bash
# Ver logs específicos
./scripts/troubleshoot.sh --logs

# Ou individualmente
cd ~/loki-stack
docker-compose logs loki
docker-compose logs promtail
docker-compose logs grafana
docker-compose logs traefik
```

## 📈 Monitoramento

### Métricas Importantes
- **Taxa de ingestão**: logs/segundo
- **Uso de disco**: crescimento dos dados
- **Erros de sistema**: falhas críticas
- **Tentativas de login**: segurança

### Alertas Configurados
- **Alto volume de logs**
- **Taxa alta de erros**
- **Falhas de login**
- **Erros do kernel**
- **Serviços fora do ar**

## 🔄 Backup e Restore

### Criar Backup
```bash
cd ~/loki-stack
./scripts/backup.sh
```

### Restaurar Backup
```bash
# Parar serviços
docker-compose down

# Restaurar dados
tar -xzf ~/loki-backups/loki-stack-backup-YYYYMMDD_HHMMSS.tar.gz

# Reiniciar
docker-compose up -d
```

## 📚 Documentação Completa

Para documentação detalhada, consulte os guias em `docs/obsidian-vault/Grafana-Loki-Guide/`:

- **Installation/** - Guias de instalação
- **Configuration/** - Configuração avançada
- **Docker-Logs/** - Configuração de logs do Docker
- **Server-Logs/** - Configuração de logs do servidor
- **Security/** - Segurança e autenticação

## 🎬 YouTube Tools

O projeto inclui ferramentas para extrair transcripts de vídeos do YouTube. Veja `youtube-tools/` para mais detalhes.

## 🆘 Suporte

### Comandos de Diagnóstico
```bash
# Diagnóstico completo
./scripts/troubleshoot.sh

# Status rápido
./scripts/quick-start.sh

# Monitoramento contínuo
watch -n 30 'cd ~/loki-stack && ./scripts/monitor.sh'
```

### Informações do Sistema
```bash
# Versões instaladas
docker --version
docker-compose --version

# Status dos serviços
systemctl status docker

# Uso de recursos
docker stats
```

## ⚠️ Notas Importantes

1. **Primeiro uso**: Aceite os certificados SSL auto-assinados no navegador
2. **Produção**: Altere todas as senhas padrão
3. **Backup**: Configure backup automatizado para dados importantes
4. **Monitoramento**: Verifique regularmente o uso de disco
5. **Segurança**: Monitore logs de autenticação e acesso

## 🎯 Próximos Passos

1. **Explore o Grafana** e familiarize-se com as queries
2. **Configure alertas** personalizados conforme sua necessidade
3. **Adicione logs** de suas aplicações
4. **Customize dashboards** para seu ambiente
5. **Implemente backup** automatizado

---

**✅ Sistema de logs centralizado funcionando!** 

Para suporte adicional, execute `./scripts/troubleshoot.sh` ou consulte a documentação completa em `docs/`.