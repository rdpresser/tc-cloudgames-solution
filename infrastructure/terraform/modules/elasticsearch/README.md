# Elasticsearch Module for Azure

Este módulo Terraform provisiona um cluster Elasticsearch no Azure usando Azure Container Instances (ACI) com armazenamento persistente e monitoramento opcional.

## Características

- **Elasticsearch 7.17.9** em container
- **Kibana opcional** para visualização
- **Armazenamento persistente** via Azure File Share
- **Monitoramento** com Application Insights e Log Analytics
- **Health checks** automáticos
- **Network Security Group** configurado
- **Backup automático** com versionamento de blobs

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Container Instance                 │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Elasticsearch │    │     Kibana      │                │
│  │   Port: 9200    │    │   Port: 5601    │                │
│  │   Memory: 4GB   │    │   Memory: 2GB   │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Azure Storage Account                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   File Share    │    │   Blob Storage  │                │
│  │   (Data)        │    │   (Backups)     │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Uso

### Exemplo Básico

```hcl
module "elasticsearch" {
  source = "../modules/elasticsearch"

  name_prefix         = "myapp-dev"
  location            = "eastus2"
  resource_group_name = "myapp-dev-rg"
  
  tags = {
    Environment = "dev"
    Project     = "myapp"
  }
}
```

### Exemplo Completo

```hcl
module "elasticsearch" {
  source = "../modules/elasticsearch"

  name_prefix         = "myapp-prod"
  location            = "eastus2"
  resource_group_name = "myapp-prod-rg"
  
  # Elasticsearch configuration
  elasticsearch_cpu              = 4
  elasticsearch_memory           = 8
  elasticsearch_java_heap_size   = "4g"
  
  # Kibana configuration
  enable_kibana = true
  kibana_cpu    = 2
  kibana_memory = 4
  
  # Storage configuration
  storage_replication_type = "GRS"
  storage_quota_gb        = 500
  
  # Monitoring
  enable_monitoring = true
  
  # Network security
  allowed_source_ips   = ["10.0.0.0/8", "192.168.0.0/16"]
  enable_private_access = false
  
  tags = {
    Environment = "prod"
    Project     = "myapp"
    CostCenter  = "Engineering"
  }
}
```

## Variáveis

### Obrigatórias

| Nome | Tipo | Descrição |
|------|------|-----------|
| `name_prefix` | `string` | Prefixo para nomenclatura de recursos |
| `location` | `string` | Região do Azure |
| `resource_group_name` | `string` | Nome do Resource Group |

### Opcionais

| Nome | Tipo | Padrão | Descrição |
|------|------|--------|-----------|
| `elasticsearch_cpu` | `number` | `2` | CPU cores para Elasticsearch |
| `elasticsearch_memory` | `number` | `4` | Memória em GB para Elasticsearch |
| `elasticsearch_java_heap_size` | `string` | `"2g"` | Tamanho do heap Java |
| `enable_kibana` | `bool` | `false` | Habilitar Kibana |
| `kibana_cpu` | `number` | `1` | CPU cores para Kibana |
| `kibana_memory` | `number` | `2` | Memória em GB para Kibana |
| `storage_replication_type` | `string` | `"LRS"` | Tipo de replicação do storage |
| `storage_quota_gb` | `number` | `100` | Quota de armazenamento em GB |
| `enable_monitoring` | `bool` | `true` | Habilitar monitoramento |
| `allowed_source_ips` | `list(string)` | `["0.0.0.0/0"]` | IPs permitidos para acesso |
| `enable_private_access` | `bool` | `false` | Acesso privado apenas |

## Outputs

### Informações de Conexão

| Nome | Descrição |
|------|-----------|
| `elasticsearch_url` | URL completa do Elasticsearch |
| `elasticsearch_host` | Hostname do Elasticsearch |
| `elasticsearch_port` | Porta do Elasticsearch |
| `connection_string` | String de conexão para aplicações |

### Informações do Container

| Nome | Descrição |
|------|-----------|
| `container_group_id` | ID do Container Group |
| `container_group_name` | Nome do Container Group |
| `elasticsearch_fqdn` | FQDN do Elasticsearch |
| `elasticsearch_ip_address` | IP público do Elasticsearch |

### Kibana (se habilitado)

| Nome | Descrição |
|------|-----------|
| `kibana_url` | URL do Kibana |
| `kibana_host` | Hostname do Kibana |
| `kibana_port` | Porta do Kibana |

### Armazenamento

| Nome | Descrição |
|------|-----------|
| `storage_account_name` | Nome da Storage Account |
| `storage_account_id` | ID da Storage Account |
| `storage_share_name` | Nome do File Share |

### Monitoramento (se habilitado)

| Nome | Descrição |
|------|-----------|
| `application_insights_id` | ID do Application Insights |
| `log_analytics_workspace_id` | ID do Log Analytics Workspace |

## Configuração de Aplicações

### Variáveis de Ambiente

```bash
# Elasticsearch
ELASTICSEARCH__HOST=your-elasticsearch-fqdn
ELASTICSEARCH__PORT=9200
ELASTICSEARCH__URL=http://your-elasticsearch-fqdn:9200

# Kibana (se habilitado)
KIBANA__HOST=your-elasticsearch-fqdn
KIBANA__PORT=5601
KIBANA__URL=http://your-elasticsearch-fqdn:5601
```

### Connection String

```csharp
// Para aplicações .NET
var connectionString = "http://your-elasticsearch-fqdn:9200";
```

## Monitoramento

### Health Checks

- **Elasticsearch**: `http://your-elasticsearch-fqdn:9200/_cluster/health`
- **Kibana**: `http://your-elasticsearch-fqdn:5601/api/status`

### Logs

Os logs são enviados automaticamente para o Log Analytics Workspace (se habilitado).

### Métricas

As métricas são coletadas pelo Application Insights (se habilitado).

## Segurança

### Network Security Group

O módulo cria automaticamente um NSG com as seguintes regras:

- **Porta 9200**: Acesso HTTP ao Elasticsearch
- **Porta 9300**: Comunicação interna do cluster
- **Porta 5601**: Acesso ao Kibana (se habilitado)

### Restrições de IP

Configure `allowed_source_ips` para restringir o acesso:

```hcl
allowed_source_ips = ["10.0.0.0/8", "192.168.0.0/16"]
```

### Acesso Privado

Para habilitar apenas acesso privado:

```hcl
enable_private_access = true
```

## Backup e Recuperação

### Backup Automático

- **Versionamento de blobs** habilitado
- **Retenção de 7 dias** para exclusões
- **Replicação** configurável (LRS, GRS, RAGRS, ZRS)

### Recuperação

1. Pare o container
2. Restaure os dados do File Share
3. Reinicie o container

## Troubleshooting

### Problemas Comuns

1. **Container não inicia**
   - Verifique os logs no Azure Portal
   - Confirme se as portas estão abertas

2. **Elasticsearch não responde**
   - Verifique o health check: `/_cluster/health`
   - Confirme se o heap size está correto

3. **Problemas de armazenamento**
   - Verifique se o File Share está montado
   - Confirme as permissões de acesso

### Logs

```bash
# Via Azure CLI
az container logs --resource-group myapp-dev-rg --name myapp-dev-elasticsearch

# Via Azure Portal
# Container Instances > myapp-dev-elasticsearch > Logs
```

## Custos

### Estimativa Mensal (East US 2)

| Configuração | CPU | Memória | Storage | Custo Aproximado |
|--------------|-----|---------|---------|------------------|
| Básica | 2 | 4GB | 100GB | $50-80 |
| Padrão | 4 | 8GB | 500GB | $120-180 |
| Avançada | 4 | 8GB | 1TB | $150-220 |

*Valores aproximados, sujeitos a alterações*

## Limitações

- **ACI**: Máximo de 4 CPU cores e 16GB de RAM
- **File Share**: Máximo de 5TB
- **Elasticsearch**: Single-node apenas
- **Kibana**: Uma instância apenas

## Próximos Passos

Para produção, considere:

1. **Elasticsearch Service** (Azure Search)
2. **AKS** para clusters multi-node
3. **Azure Monitor** para métricas avançadas
4. **Azure Backup** para backup automatizado

## Suporte

Para problemas ou dúvidas:

1. Verifique os logs do container
2. Consulte a documentação do Elasticsearch
3. Abra uma issue no repositório

