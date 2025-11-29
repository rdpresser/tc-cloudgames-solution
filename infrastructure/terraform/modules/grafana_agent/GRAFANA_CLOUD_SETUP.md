# Integração AKS com Grafana Cloud

Este guia explica como conectar seu cluster AKS ao Grafana Cloud para monitoramento centralizado.

## 📊 Arquitetura de Monitoramento

```
┌─────────────────────────────────────────────────────────┐
│  AKS Cluster                                            │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ Your Pods│  │ Kube API │  │  Nodes   │             │
│  │  Metrics │  │  Metrics │  │  Metrics │             │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
│       │             │             │                     │
│       └─────────────┴─────────────┘                     │
│                     │                                   │
│            ┌────────▼────────┐                         │
│            │  Grafana Agent  │                         │
│            │   (DaemonSet)   │                         │
│            └────────┬────────┘                         │
└─────────────────────┼───────────────────────────────────┘
                      │ HTTPS (Remote Write)
                      ▼
         ┌────────────────────────┐
         │   Grafana Cloud        │
         │                        │
         │  • Prometheus (Metrics)│
         │  • Loki (Logs)         │
         │  • Dashboards          │
         └────────────────────────┘
```

## 🚀 Passo a Passo: Obter Credenciais do Grafana Cloud

### 1️⃣ **Acessar Grafana Cloud**

1. Acesse: https://grafana.com/auth/sign-in
2. Faça login com sua conta
3. Selecione sua Stack (ex: `yourcompany.grafana.net`)

### 2️⃣ **Obter Credenciais do Prometheus**

#### Via Grafana Cloud Portal:

1. No menu lateral, clique em **"Connections"** → **"Add new connection"**
2. Procure por **"Hosted Prometheus metrics"** ou **"Prometheus"**
3. Clique em **"Configure"**
4. Você verá as credenciais:

```
Remote Write Endpoint:
https://prometheus-prod-XX-XX-X.grafana.net/api/prom/push

Username / Instance ID:
123456

Password / API Key:
glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### Via CLI (Alternative):

1. Acesse **"My Account"** → **"API Keys"**
2. Clique em **"Create API Key"**
3. Configure:
   - **Name**: `aks-metrics-writer`
   - **Role**: `MetricsPublisher`
   - **Expiration**: 1 year (or never)
4. Clique em **"Add API Key"**
5. **COPIE A CHAVE IMEDIATAMENTE** (você não conseguirá ver novamente!)

### 3️⃣ **Obter URL e Username do Prometheus**

#### Encontrar URL e Username:

1. Vá para **"Administration"** → **"Settings"**
2. Na seção **"Grafana Cloud"**, você verá:

```yaml
Prometheus:
  URL: https://prometheus-prod-01-eu-west-0.grafana.net
  User: 123456
  
Loki:
  URL: https://logs-prod-eu-west-0.grafana.net
  User: 123456
```

**OU**

1. Vá para **"Connections"** → **"Data sources"**
2. Clique em **"Prometheus"** (ou **"grafanacloud-yourstack-prom"**)
3. Na configuração, você verá:
   - **URL**: `https://prometheus-prod-XX-XX-X.grafana.net`
   - Scroll até **"Basic Auth Details"**:
     - **User**: `123456` (seu Instance ID)

### 4️⃣ **Adicionar Variáveis no Terraform Cloud**

Agora você precisa adicionar essas credenciais como variáveis no Terraform Cloud:

#### No Terraform Cloud:

1. Acesse: https://app.terraform.io
2. Vá para sua Organization: `rdpresser_tccloudgames_fiap`
3. Selecione Workspace: `tc-cloudgames-foundation-dev`
4. Clique em **"Variables"**
5. Adicione as seguintes variáveis:

| Variable Name | Value | Sensitive? | Description |
|---------------|-------|------------|-------------|
| `grafana_cloud_prometheus_url` | `https://prometheus-prod-XX-XX-X.grafana.net` | ❌ No | Prometheus remote write URL |
| `grafana_cloud_prometheus_username` | `123456` | ❌ No | Your Instance ID |
| `grafana_cloud_prometheus_api_key` | `glc_xxxxx...` | ✅ **YES** | Prometheus API Key |
| `grafana_cloud_loki_url` | `https://logs-prod-eu-west-0.grafana.net` | ❌ No | (Opcional) Loki URL |
| `grafana_cloud_loki_username` | `123456` | ❌ No | (Opcional) Same Instance ID |
| `grafana_cloud_loki_api_key` | `glc_xxxxx...` | ✅ **YES** | (Opcional) Loki API Key |

⚠️ **IMPORTANTE**: Marque as API Keys como **SENSITIVE** para proteger as credenciais!

### 5️⃣ **Adicionar Variáveis no foundation/variables.tf**

Edite `infrastructure/terraform/foundation/variables.tf` e adicione:

```hcl
# =============================================================================
# Grafana Cloud Configuration
# =============================================================================

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write URL"
  type        = string
}

variable "grafana_cloud_prometheus_username" {
  description = "Grafana Cloud Prometheus username (Instance ID)"
  type        = string
}

variable "grafana_cloud_prometheus_api_key" {
  description = "Grafana Cloud Prometheus API key"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_loki_url" {
  description = "Grafana Cloud Loki URL (optional)"
  type        = string
  default     = ""
}

variable "grafana_cloud_loki_username" {
  description = "Grafana Cloud Loki username (optional)"
  type        = string
  default     = ""
}

variable "grafana_cloud_loki_api_key" {
  description = "Grafana Cloud Loki API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}
```

### 6️⃣ **Adicionar Módulo Grafana Agent no main.tf**

Edite `infrastructure/terraform/foundation/main.tf` e adicione:

```hcl
# =============================================================================
# Grafana Agent Module - Metrics to Grafana Cloud
# =============================================================================
module "grafana_agent" {
  source = "../modules/grafana_agent"

  cluster_name        = module.aks.cluster_name
  resource_group_name = module.resource_group.name

  grafana_cloud_prometheus_url      = var.grafana_cloud_prometheus_url
  grafana_cloud_prometheus_username = var.grafana_cloud_prometheus_username
  grafana_cloud_prometheus_api_key  = var.grafana_cloud_prometheus_api_key

  # Optional: Loki for logs
  grafana_cloud_loki_url      = var.grafana_cloud_loki_url
  grafana_cloud_loki_username = var.grafana_cloud_loki_username
  grafana_cloud_loki_api_key  = var.grafana_cloud_loki_api_key

  labels = merge(
    local.common_tags,
    {
      "app.kubernetes.io/name"     = "grafana-agent"
      "app.kubernetes.io/instance" = "grafana-agent"
    }
  )

  depends_on = [
    module.aks,
    module.argocd
  ]
}
```

### 7️⃣ **Adicionar Outputs no outputs.tf**

Edite `infrastructure/terraform/foundation/outputs.tf` e adicione:

```hcl
# =============================================================================
# Grafana Agent Outputs
# =============================================================================

output "grafana_agent_info" {
  description = "Grafana Agent deployment details"
  value = {
    namespace           = module.grafana_agent.namespace
    helm_release_name   = module.grafana_agent.helm_release_name
    helm_release_version = module.grafana_agent.helm_release_version
    prometheus_url      = module.grafana_agent.grafana_cloud_prometheus_url
  }
}
```

## 🎯 O que o Grafana Agent vai Coletar

### ✅ Métricas Coletadas Automaticamente:

1. **Node Metrics** (via kubelet):
   - CPU, Memory, Disk, Network
   - Node status, conditions
   
2. **Container Metrics** (via cAdvisor):
   - CPU, Memory per container
   - Network I/O per container
   - Disk I/O per container

3. **Kube State Metrics** (se instalado):
   - Deployments, Pods, Services status
   - ReplicaSets, DaemonSets
   - PersistentVolumes

4. **Custom App Metrics** (suas APIs .NET):
   - Qualquer pod com annotation `prometheus.io/scrape: "true"`
   - Métricas expostas em `/metrics`

### 📊 Exemplo: Configurar Suas APIs para Exportar Métricas

No seu Deployment Kubernetes (.NET APIs), adicione annotations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-api
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"   # ← Habilita scraping
        prometheus.io/port: "8080"      # ← Porta das métricas
        prometheus.io/path: "/metrics"  # ← Path das métricas
    spec:
      containers:
      - name: users-api
        image: tccloudgamesdevcr8nacr.azurecr.io/users-api:latest
        ports:
        - containerPort: 8080
```

No seu código .NET, instale o pacote:

```bash
dotnet add package prometheus-net.AspNetCore
```

Configure no `Program.cs`:

```csharp
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// ... outros serviços ...

var app = builder.Build();

// Expor métricas Prometheus
app.UseMetricServer();      // Expõe /metrics
app.UseHttpMetrics();        // Coleta métricas HTTP automaticamente

app.Run();
```

## 🔍 Verificar se está Funcionando

Após o `terraform apply`:

### 1️⃣ Verificar Grafana Agent no AKS:

```bash
# Conectar ao AKS
az aks get-credentials --resource-group tc-cloudgames-solution-dev-rg --name tc-cloudgames-dev-cr8n-aks

# Verificar pods do Grafana Agent
kubectl get pods -n grafana-agent

# Ver logs do Grafana Agent
kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent --tail=100
```

### 2️⃣ Verificar Métricas no Grafana Cloud:

1. Acesse seu Grafana Cloud: `https://yourcompany.grafana.net`
2. Vá para **"Explore"**
3. Selecione data source **"Prometheus"**
4. Digite query de teste:

```promql
# Ver nodes do cluster
up{job="kubelet"}

# Ver pods
kube_pod_info

# Ver CPU dos containers
container_cpu_usage_seconds_total
```

5. Você deve ver dados chegando em tempo real!

### 3️⃣ Criar Dashboards:

1. No Grafana Cloud, vá para **"Dashboards"** → **"Import"**
2. Importe dashboards prontos:
   - **Kubernetes Cluster Monitoring**: ID `7249`
   - **Kubernetes Pod Monitoring**: ID `6417`
   - **Node Exporter Full**: ID `1860`

## 🎯 Resumo: Por que Grafana Agent?

| Solução | Azure Monitor | Grafana Agent |
|---------|--------------|---------------|
| **Custo** | Pago por GB ingerido | Incluído no Grafana Cloud |
| **Flexibilidade** | Limitado a Azure | Qualquer Prometheus exporter |
| **Custom Metrics** | Complexo | Simples (annotations) |
| **Dashboards** | Azure Portal | Grafana Cloud (melhor UX) |
| **Vendor Lock** | Azure | Multi-cloud |
| **Você já tem?** | ❌ Não | ✅ SIM (Grafana Cloud) |

**Recomendação Final**: Use **Grafana Agent** + **Grafana Cloud** para métricas de Kubernetes/Apps, e mantenha o **Azure Monitor Data Source** no Grafana para métricas de infraestrutura Azure (VMs, Storage, etc.).

Isso te dá o melhor dos dois mundos! 🚀
