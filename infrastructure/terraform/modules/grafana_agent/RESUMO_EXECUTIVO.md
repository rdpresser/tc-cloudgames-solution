# 📊 Integração AKS → Grafana Cloud: Resumo Executivo

## ❓ Sua Pergunta Original

> "Eu já tenho Azure Monitor integrado com Grafana Cloud como data source. Isso é suficiente ou preciso conectar o AKS ao Grafana Cloud de outra forma?"

## ✅ Resposta Curta

**Você precisa de AMBOS**:

1. ✅ **Azure Monitor Data Source** (você já tem) → Para métricas de **infraestrutura Azure**
2. ✅ **Grafana Agent no AKS** (falta configurar) → Para métricas de **Kubernetes e aplicações**

## 🎯 Por Que Precisa dos Dois?

### Azure Monitor Data Source (Você já tem ✅)

**O que cobre:**
- ✅ Métricas de VMs, Disks, Network do Azure
- ✅ Métricas de SQL Database, Redis, Storage
- ✅ Logs do Azure Activity Log
- ✅ **Container Insights** (básico - se habilitado)

**O que NÃO cobre bem:**
- ❌ Métricas detalhadas de **pods/containers**
- ❌ Métricas de **aplicação** (.NET APIs)
- ❌ **Custom Prometheus metrics** exportadas pelas suas apps
- ❌ **Service Mesh metrics** (Istio, Linkerd)
- ❌ Métricas de **Redis Exporter**, **PostgreSQL Exporter**, etc.

### Grafana Agent no AKS (Falta configurar 🔧)

**O que cobre:**
- ✅ **Todas as métricas de Kubernetes** (kubelet, cAdvisor, kube-state-metrics)
- ✅ **Métricas de aplicação** (suas APIs .NET com prometheus-net)
- ✅ **Custom Exporters** (redis_exporter, postgres_exporter, etc.)
- ✅ **Logs de containers** (opcional, via Loki)
- ✅ **Traces** (opcional, via Tempo)

## 🏗️ Arquitetura Recomendada

```
┌─────────────────────────────────────────────────────────┐
│                    Grafana Cloud                        │
│                                                          │
│  ┌──────────────────┐      ┌──────────────────┐       │
│  │ Azure Monitor DS │      │   Prometheus      │       │
│  │                  │      │   (Grafana Agent) │       │
│  │ • VMs, Disks    │      │ • K8s Metrics     │       │
│  │ • Azure PaaS    │      │ • App Metrics     │       │
│  │ • Activity Logs │      │ • Custom Exporters│       │
│  └────────▲─────────┘      └────────▲─────────┘       │
│           │                         │                   │
└───────────┼─────────────────────────┼───────────────────┘
            │                         │
            │                         │
            │                         │
┌───────────▼─────────────────────────▼───────────────────┐
│               Azure Infrastructure                       │
│                                                          │
│  ┌──────────────────┐      ┌──────────────────┐       │
│  │  Azure Services  │      │   AKS Cluster    │       │
│  │                  │      │                  │       │
│  │ • PostgreSQL     │      │ ┌──────────────┐ │       │
│  │ • Redis          │      │ │ Grafana Agent│ │       │
│  │ • Storage        │      │ │ (DaemonSet)  │ │       │
│  │ • Service Bus    │      │ └──────────────┘ │       │
│  │                  │      │                  │       │
│  └──────────────────┘      │ ┌──────────────┐ │       │
│                            │ │  Your Apps   │ │       │
│                            │ │  (APIs .NET) │ │       │
│                            │ └──────────────┘ │       │
│                            └──────────────────┘       │
└──────────────────────────────────────────────────────────┘
```

## 🚀 Próximos Passos (5 minutos)

### 1️⃣ Obter Credenciais do Grafana Cloud

Acesse: https://grafana.com → Your Stack → **Connections** → **Prometheus**

Copie:
- `Prometheus URL`: `https://prometheus-prod-XX-XX-X.grafana.net`
- `Username`: `123456` (Instance ID)
- `API Key`: `glc_xxxxxxxxxxxxxxxxxxxxx` (criar se não tiver)

### 2️⃣ Adicionar no Terraform Cloud

Acesse: https://app.terraform.io → `tc-cloudgames-foundation-dev` → **Variables**

Adicionar:
```
grafana_cloud_prometheus_url      = https://prometheus-prod-XX-XX-X.grafana.net
grafana_cloud_prometheus_username = 123456
grafana_cloud_prometheus_api_key  = glc_xxxxx... (SENSITIVE!)
```

### 3️⃣ Atualizar Terraform

Já criei os arquivos para você:
- ✅ `modules/grafana_agent/main.tf`
- ✅ `modules/grafana_agent/variables.tf`
- ✅ `modules/grafana_agent/outputs.tf`
- ✅ `modules/grafana_agent/GRAFANA_CLOUD_SETUP.md`

**Falta apenas:**
1. Adicionar variáveis no `foundation/variables.tf`
2. Adicionar módulo no `foundation/main.tf`
3. Adicionar outputs no `foundation/outputs.tf`

### 4️⃣ Aplicar Terraform

```bash
terraform apply
```

O Grafana Agent será instalado automaticamente e começará a enviar métricas!

## 📊 Resultado Final

Você terá no Grafana Cloud:

### Dashboard 1: Azure Infrastructure (Azure Monitor DS)
- VMs, Storage, Network
- PostgreSQL, Redis, Service Bus metrics
- Azure Activity Logs

### Dashboard 2: Kubernetes Cluster (Grafana Agent)
- Node CPU, Memory, Disk
- Pod CPU, Memory, Network
- Deployment status
- Container restart counts

### Dashboard 3: Application Metrics (Grafana Agent)
- HTTP request rate/latency
- .NET custom metrics
- Database connection pools
- Redis cache hit rate

## 💰 Custos

| Solução | Custo Adicional |
|---------|----------------|
| **Azure Monitor DS** | $0 (você já tem) |
| **Grafana Agent** | $0 (incluído no Grafana Cloud Free tier até 10k series) |
| **Grafana Cloud** | $0 - $299/mês (dependendo do plano) |

**Nota**: Se você já paga Grafana Cloud, não há custo adicional para adicionar o Grafana Agent!

## ✅ Checklist Final

- [ ] Obter credenciais do Grafana Cloud
- [ ] Adicionar variáveis no Terraform Cloud
- [ ] Atualizar `foundation/variables.tf`
- [ ] Atualizar `foundation/main.tf` (adicionar módulo grafana_agent)
- [ ] Atualizar `foundation/outputs.tf`
- [ ] Executar `terraform apply`
- [ ] Verificar pods: `kubectl get pods -n grafana-agent`
- [ ] Verificar métricas no Grafana Cloud (query: `up{job="kubelet"}`)
- [ ] Importar dashboards prontos (IDs: 7249, 6417, 1860)

## 🎁 Bônus: Dashboards Recomendados

Importar no Grafana Cloud:

1. **Kubernetes Cluster Monitoring**: https://grafana.com/grafana/dashboards/7249
2. **Kubernetes Pod Monitoring**: https://grafana.com/grafana/dashboards/6417
3. **Node Exporter Full**: https://grafana.com/grafana/dashboards/1860

---

Alguma dúvida? Posso te ajudar com qualquer passo específico! 🚀
