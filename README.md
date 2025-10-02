# 🚀 Grafana Loki Stack - Deploy Automático

Sistema completo de logs centralizados baseado no **Grafana Loki**, com deploy automático e configuração completa.

## 📋 O que será instalado

- **🔍 Grafana Loki** - Agregação e armazenamento de logs
- **📝 Promtail** - Coleta de logs do sistema e Docker
- **📊 Grafana** - Interface de visualização e dashboards
- **🔀 Traefik** - Reverse proxy com SSL automático
- **🔔 Alertas** - Regras de alerta pré-configuradas
- **📈 Dashboards** - Painéis prontos para monitoramento

## ⚡ Quick Start

### 1. Deploy Automático

```bash
# Tornar executável e executar
chmod +x deploy-loki-stack.sh
./deploy-loki-stack.sh
```

### 2. Verificar Instalação

```bash
# Verificação rápida
chmod +x quick-start.sh
./quick-start.sh
```

### 3. Acessar Interfaces

- **Grafana**: https://grafana.localhost (admin/admin123)
- **Loki API**: https://loki.localhost
- **Traefik Dashboard**: https://traefik.localhost (admin/admin123)

## 🛠️ Scripts Disponíveis

### Deploy Principal
```bash
./deploy-loki-stack.sh    # Instalação completa automática
```

### Verificação e Testes
```bash
./quick-start.sh          # Verificação rápida pós-instalação
./troubleshoot.sh         # Diagnóstico completo
./troubleshoot.sh --logs  # Ver logs dos serviços
./troubleshoot.sh --fix   # Corrigir problemas comuns
```

### Gerenciamento (após instalação)
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

## 🔧 Configuração Avançada

### Estrutura de Diretórios
```
~/loki-stack/
├── config/
│   ├── loki/           # Configuração do Loki
│   ├── promtail/       # Configuração do Promtail
│   ├── grafana/        # Configuração do Grafana
│   └── traefik/        # Configuração do Traefik
├── data/               # Dados persistentes
├── logs/               # Logs personalizados
├── scripts/            # Scripts auxiliares
└── docker-compose.yml  # Configuração principal
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
./troubleshoot.sh --fix
```

#### Logs não aparecem
```bash
# Verificar permissões
sudo usermod -a -G adm $USER
sudo usermod -a -G syslog $USER

# Reiniciar
./troubleshoot.sh --reset
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
./troubleshoot.sh --clean
```

### Logs de Debug
```bash
# Ver logs específicos
./troubleshoot.sh --logs

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

Para documentação detalhada, consulte os guias no diretório `obsidian-vault/Grafana-Loki-Guide/`:

- **Installation/** - Guias de instalação
- **Configuration/** - Configuração avançada
- **Docker-Logs/** - Configuração de logs do Docker
- **Server-Logs/** - Configuração de logs do servidor
- **Security/** - Segurança e autenticação

## 📤 Envio para GitHub

### Configuração Inicial (apenas uma vez)
```bash
./git-setup.sh    # Configurar Git e GitHub
```

### Enviar Arquivos para GitHub
```bash
# Envio simples com mensagem automática
./git-push.sh

# Envio com mensagem personalizada
./git-push.sh "Added new feature"
./git-push.sh "Fixed deployment script"
./git-push.sh "Updated documentation"

# Ver status do repositório
./git-push.sh --status

# Ver informações do repositório
./git-push.sh --info
```

## 🆘 Suporte

### Comandos de Diagnóstico
```bash
# Diagnóstico completo
./troubleshoot.sh

# Status rápido
./quick-start.sh

# Monitoramento contínuo
watch -n 30 './scripts/monitor.sh'
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

Para suporte adicional, execute `./troubleshoot.sh` ou consulte a documentação completa.
