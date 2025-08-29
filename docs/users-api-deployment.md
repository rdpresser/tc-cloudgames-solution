# TC CloudGames - Users API Deployment Guide

Este guia documenta o pipeline moderno de deployment da API Users que elimina o gerenciamento manual de segredos usando **System Managed Identity** e **RBAC**.

## 🏗️ Arquitetura da Solução

### Foundation Infrastructure (Compartilhada)
```
infrastructure/terraform/foundation/
├── main.tf              # 8 módulos de infraestrutura base
├── outputs.tf           # Outputs para outros serviços
└── variables.tf         # Variáveis de configuração
```

**Recursos Criados:**
- Resource Group
- PostgreSQL Flexible Server
- Azure Container Registry (ACR)
- Redis Cache
- Log Analytics Workspace
- Container App Environment
- **Key Vault com secrets populados automaticamente**
- Service Bus Namespace

### Users API Service
```
src/Users/
├── azure.yaml           # Configuração AZD para Container Apps
├── Dockerfile           # Container otimizado para .NET 9.0
├── Users.csproj         # Projeto .NET com FastEndpoints
├── Program.cs           # Configuração com System MI
├── Infrastructure/      # DbContext e configurações
├── Models/              # Entidades do domínio
└── Endpoints/           # FastEndpoints RESTful
```

### Container App Module (Reutilizável)
```
infrastructure/terraform/modules/container_app/
├── variables.tf         # Parâmetros configuráveis
├── main.tf             # Container App + System MI + RBAC
└── outputs.tf          # Informações de deployment
```

## 🚀 Pipeline de Deployment

### 1. Build Job
- 🏗️ Constrói imagem Docker otimizada
- 🏷️ Gera tag com timestamp + commit SHA
- 📦 Faz push para ACR usando Azure CLI
- 🔐 Usa credenciais GitHub OIDC (sem secrets!)

### 2. Deploy Job  
- 📦 Instala Azure Developer CLI
- 🚀 Executa `azd deploy` com configuração automática
- 🆔 Container App criado com System Managed Identity
- 🔐 RBAC configurado automaticamente para Key Vault
- ✅ Teste de saúde do deployment

### 3. Summary Job
- 📊 Relatório completo do deployment
- 🔗 Links diretos para Azure Portal
- ✅ Status e próximos passos

## 🔑 Benefícios da Abordagem System MI

### ❌ Abordagem Antiga (Manual)
```yaml
# Pipeline antigo - busca manual de secrets
- name: Get secrets from Key Vault
  run: |
    DB_CONNECTION=$(az keyvault secret show --name postgres-connection-string --vault-name $KV_NAME --query value -o tsv)
    REDIS_CONNECTION=$(az keyvault secret show --name redis-connection-string --vault-name $KV_NAME --query value -o tsv)
```

### ✅ Abordagem Nova (System MI)
```yaml
# Container App automaticamente acessa Key Vault
secrets:
  - name: postgres-connection-string
    keyVaultUrl: https://{KEY_VAULT_NAME}.vault.azure.net/secrets/postgres-connection-string
env:
  - name: DATABASE_CONNECTION_STRING
    secretRef: postgres-connection-string
```

## 📋 Pré-requisitos

### 1. Foundation Infrastructure
```bash
# Deploye a infraestrutura base primeiro
cd infrastructure/terraform/foundation
terraform init
terraform plan
terraform apply
```

### 2. GitHub Secrets
```
AZURE_SUBSCRIPTION_ID   # ID da subscription Azure
AZURE_TENANT_ID         # ID do tenant Azure AD
AZURE_CLIENT_ID         # ID da aplicação OIDC
```

### 3. Permissões RBAC
- A aplicação GitHub OIDC precisa de:
  - `Contributor` no Resource Group
  - `Key Vault Secrets User` no Key Vault

## 🚀 Como Usar

### Deployment Automático
```bash
# Push para main = deployment automático para dev
git push origin main

# Deployment manual para outros environments
gh workflow run users_api_deploy.yml -f environment=staging
```

### Deployment via AZD Local
```bash
cd src/Users
azd init
azd up
```

## 🔍 Monitoramento

### Health Checks
- **Endpoint**: `https://{app-url}/health`
- **Checks**: PostgreSQL, Redis, Service Bus
- **Format**: JSON com status e métricas

### Logs e Métricas
- Log Analytics Workspace integrado
- Container App logs automáticos
- Application Insights (futuro)

## 🛡️ Segurança

### System Managed Identity
- ✅ Sem credenciais hardcoded
- ✅ Rotação automática de credenciais
- ✅ Princípio do menor privilégio
- ✅ Auditoria completa de acesso

### Container Security
- ✅ Imagem base Alpine (minimal)
- ✅ Non-root user
- ✅ Multi-stage build
- ✅ Health checks integrados

### Key Vault Integration
- ✅ Secrets populados via Terraform
- ✅ RBAC em vez de Access Policies
- ✅ Referências automáticas no Container App
- ✅ Sem exposição de secrets em logs

## 📈 Próximos Passos

### Expansão para Outros Serviços
1. **Games API**: Reutilizar módulo `container_app`
2. **Payments API**: Adicionar PCI DSS compliance
3. **API Gateway**: Centralizar autenticação

### Melhorias de DevOps
1. **Blue/Green Deployments**: Usar AZD revisions
2. **Auto-scaling**: Métricas personalizadas
3. **Disaster Recovery**: Multi-region deployment

### Observabilidade
1. **Application Insights**: Métricas APM
2. **Distributed Tracing**: Entre microserviços
3. **Custom Dashboards**: KPIs de negócio

## 🎯 Conclusão

Este pipeline representa a evolução para práticas modernas de DevOps:

- **Segurança**: System MI elimina gerenciamento manual de secrets
- **Automação**: AZD + Terraform para infrastructure as code
- **Observabilidade**: Health checks e logs estruturados
- **Escalabilidade**: Container Apps com auto-scaling
- **Maintainability**: Módulos Terraform reutilizáveis

🚀 **Ready for production!** 🎮
