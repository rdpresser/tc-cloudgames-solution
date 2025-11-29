# 🔑 Guia: Obter Credenciais do Grafana Cloud

## 📋 Passo a Passo Completo

### **PASSO 1: Acessar Grafana Cloud**

1. Abra seu navegador
2. Acesse: **https://grafana.com**
3. Clique em **"Sign In"** no canto superior direito
4. Faça login com suas credenciais

---

### **PASSO 2: Selecionar Sua Stack**

Após o login, você verá suas stacks disponíveis:

```
📊 My Stacks
┌─────────────────────────────────────┐
│  yourcompany.grafana.net           │  ← Clique aqui
│  Status: Active                     │
│  Region: EU West                    │
└─────────────────────────────────────┘
```

**Ação**: Clique na sua stack (ex: `yourcompany.grafana.net`)

---

### **PASSO 3: Acessar Configurações do Prometheus**

#### **Opção A: Via "Connections" (Recomendado)**

1. No menu lateral esquerdo, clique em **"Connections"**
2. Clique em **"Add new connection"** (botão azul no topo)
3. Na caixa de busca, digite: **"Prometheus"**
4. Clique em **"Prometheus"** ou **"Hosted Prometheus metrics"**
5. Clique no botão **"Via Grafana Agent, Prometheus and OpenTelemetry"**

#### **Opção B: Via "Administration"**

1. No menu lateral esquerdo, clique em **"Administration"** (ícone de engrenagem)
2. Clique em **"Settings"**
3. Role até a seção **"Grafana Cloud"**
4. Você verá algo assim:

```yaml
📊 Grafana Cloud Details

Prometheus:
  Remote Write Endpoint: https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
  Remote Write User: 123456
  
Loki:
  URL: https://logs-prod-eu-west-0.grafana.net
  User: 123456
```

---

### **PASSO 4: Copiar URL e Username do Prometheus**

Você verá uma tela assim:

```
┌─────────────────────────────────────────────────────────┐
│  Configure Prometheus Remote Write                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Remote Write Endpoint:                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ https://prometheus-prod-01-eu-west-0.grafana.net   │ │ ← COPIE ISSO (SEM /api/prom/push)
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Username / Instance ID:                                │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 123456                                              │ │ ← COPIE ISSO
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**⚠️ IMPORTANTE**: Copie apenas a URL BASE do Prometheus (sem `/api/prom/push` no final):
- ✅ CORRETO: `https://prometheus-prod-01-eu-west-0.grafana.net`
- ❌ ERRADO: `https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push`

**Anote:**
- **Prometheus URL**: `https://prometheus-prod-XX-XX-X.grafana.net` (sua URL será diferente)
- **Username**: `123456` (seu Instance ID será diferente)

---

### **PASSO 5: Gerar API Key**

Agora você precisa criar uma API Key para autenticação.

#### **5.1: Acessar Gerenciamento de API Keys**

1. No menu lateral esquerdo, clique no **ícone da sua organização** (geralmente no topo)
2. Clique em **"Administration"** → **"API Keys"**

**OU**

1. Clique no seu avatar/nome no canto superior direito
2. Clique em **"My Account"** ou **"Organization Settings"**
3. Clique em **"API Keys"** no menu lateral

#### **5.2: Criar Nova API Key**

1. Clique no botão **"Create API Key"** ou **"Add API Key"**
2. Preencha os campos:

```
┌─────────────────────────────────────────────────────────┐
│  Create API Key                                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Display Name:                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ aks-metrics-writer                                 │ │ ← Nome descritivo
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Role:                                                   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ MetricsPublisher                        [▼]        │ │ ← Selecione este role
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Time to Live:                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 1 year                                  [▼]        │ │ ← Ou "Never expire"
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  [Cancel]                           [Add API Key] ───┐  │
└──────────────────────────────────────────────────────│───┘
                                                       └────► Clique aqui
```

3. Clique em **"Add API Key"** ou **"Create"**

#### **5.3: Copiar a API Key**

**⚠️ ATENÇÃO: VOCÊ SÓ VERÁ A API KEY UMA VEZ!**

Após criar, você verá uma tela assim:

```
┌─────────────────────────────────────────────────────────┐
│  ✅ API Key Created Successfully                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Your API Key (copy it now, you won't see it again):   │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ glc_eyJrIjoiWGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3...   │ │
│  │ ...xyz123456789ABC                        [Copy]   │ │ ← COPIE ISSO AGORA!
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  [Close]                                                │
└─────────────────────────────────────────────────────────┘
```

**Copie imediatamente** e salve em um local seguro (ex: notepad, password manager).

A API Key sempre começa com `glc_` e é uma string longa. Exemplo:
```
glc_eyJrIjoiWGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6MTIzNDU2Nzg5IiwibiI6InRlc3QtYXBpLWtleSIsImlkIjo3ODkwMTJ9
```

---

### **PASSO 6: (Opcional) Obter Credenciais do Loki**

Se você também quiser enviar **logs** para Grafana Cloud (opcional):

1. Volte para **"Administration"** → **"Settings"**
2. Na seção **"Grafana Cloud"**, você verá:

```yaml
Loki:
  URL: https://logs-prod-eu-west-0.grafana.net
  User: 123456
```

**Anote:**
- **Loki URL**: `https://logs-prod-eu-west-0.grafana.net`
- **Loki Username**: `123456` (geralmente o mesmo que Prometheus)

Para a API Key do Loki, você pode:
- **Reutilizar a mesma API Key** que criou para Prometheus (funciona para ambos)
- **OU criar uma API Key específica** para Loki com role `LogsPublisher`

---

## 📝 Resumo: O Que Você Precisa Anotar

Ao final, você deve ter estas 3 informações:

| Item | Exemplo | Onde Encontrar |
|------|---------|----------------|
| **Prometheus URL** | `https://prometheus-prod-01-eu-west-0.grafana.net` | Connections → Prometheus → Remote Write Endpoint (sem /api/prom/push) |
| **Username (Instance ID)** | `123456` | Connections → Prometheus → Remote Write User |
| **API Key** | `glc_eyJrIjoiWGFiY...` | Administration → API Keys → Create API Key → MetricsPublisher role |

**Opcional (para logs):**
| Item | Exemplo |
|------|---------|
| **Loki URL** | `https://logs-prod-eu-west-0.grafana.net` |
| **Loki Username** | `123456` (mesmo que Prometheus) |
| **Loki API Key** | `glc_...` (pode ser a mesma) |

---

## 🔐 PASSO 7: Adicionar no Terraform Cloud

Agora você vai adicionar essas credenciais como **variáveis no Terraform Cloud**:

### **7.1: Acessar Terraform Cloud**

1. Acesse: **https://app.terraform.io**
2. Faça login
3. Vá para sua Organization: **`rdpresser_tccloudgames_fiap`**
4. Clique no Workspace: **`tc-cloudgames-foundation-dev`**

### **7.2: Adicionar Variáveis**

1. Clique na aba **"Variables"** no menu superior
2. Role até a seção **"Workspace variables"**
3. Clique em **"+ Add variable"**

### **7.3: Adicionar Variável 1 - Prometheus URL**

```
┌─────────────────────────────────────────────────────────┐
│  Add variable                                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Variable category:                                      │
│  ○ Environment variable   ● Terraform variable          │
│                                                          │
│  Key:                                                    │
│  ┌────────────────────────────────────────────────────┐ │
│  │ grafana_cloud_prometheus_url                       │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Value:                                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │ https://prometheus-prod-01-eu-west-0.grafana.net   │ │ ← Cole sua URL aqui
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Description (optional):                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Grafana Cloud Prometheus remote write URL         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ☐ Sensitive - Write only, not visible in the UI       │
│  ☐ HCL - Parse as HCL                                   │
│                                                          │
│  [Cancel]                           [Save variable]     │
└─────────────────────────────────────────────────────────┘
```

**Configuração:**
- Category: **Terraform variable** ✅
- Key: `grafana_cloud_prometheus_url`
- Value: Sua URL (ex: `https://prometheus-prod-01-eu-west-0.grafana.net`)
- Sensitive: **NÃO** ❌
- HCL: **NÃO** ❌

Clique em **"Save variable"**.

### **7.4: Adicionar Variável 2 - Username**

Clique em **"+ Add variable"** novamente:

**Configuração:**
- Category: **Terraform variable** ✅
- Key: `grafana_cloud_prometheus_username`
- Value: Seu Instance ID (ex: `123456`)
- Sensitive: **NÃO** ❌
- HCL: **NÃO** ❌

Clique em **"Save variable"**.

### **7.5: Adicionar Variável 3 - API Key** ⚠️ SENSITIVE!

Clique em **"+ Add variable"** novamente:

```
┌─────────────────────────────────────────────────────────┐
│  Add variable                                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Variable category:                                      │
│  ○ Environment variable   ● Terraform variable          │
│                                                          │
│  Key:                                                    │
│  ┌────────────────────────────────────────────────────┐ │
│  │ grafana_cloud_prometheus_api_key                   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Value:                                                  │
│  ┌────────────────────────────────────────────────────┐ │
│  │ glc_eyJrIjoiWGFiY2RlZmdoaWprbG1ub3BxcnN0...       │ │ ← Cole sua API Key aqui
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Description (optional):                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Grafana Cloud Prometheus API Key (sensitive)      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ☑ Sensitive - Write only, not visible in the UI   ◄── MARCAR!
│  ☐ HCL - Parse as HCL                                   │
│                                                          │
│  [Cancel]                           [Save variable]     │
└─────────────────────────────────────────────────────────┘
```

**Configuração:**
- Category: **Terraform variable** ✅
- Key: `grafana_cloud_prometheus_api_key`
- Value: Sua API Key completa (ex: `glc_eyJrIjoiWGFiY...`)
- **Sensitive: SIM** ✅ **← IMPORTANTE!**
- HCL: **NÃO** ❌

Clique em **"Save variable"**.

### **7.6: Habilitar Grafana Agent**

Adicione mais uma variável para habilitar o módulo:

**Configuração:**
- Category: **Terraform variable** ✅
- Key: `enable_grafana_agent`
- Value: `true`
- Sensitive: **NÃO** ❌
- **HCL: SIM** ✅ **← IMPORTANTE!** (porque é um boolean)

Clique em **"Save variable"**.

### **7.7: (Opcional) Variáveis do Loki**

Se você quiser enviar logs também, adicione:

1. **Loki URL:**
   - Key: `grafana_cloud_loki_url`
   - Value: `https://logs-prod-eu-west-0.grafana.net`
   - Sensitive: NÃO

2. **Loki Username:**
   - Key: `grafana_cloud_loki_username`
   - Value: `123456` (mesmo que Prometheus)
   - Sensitive: NÃO

3. **Loki API Key:**
   - Key: `grafana_cloud_loki_api_key`
   - Value: `glc_...` (mesma ou outra API Key)
   - **Sensitive: SIM** ✅

---

## ✅ Resultado Final no Terraform Cloud

Você deve ter estas variáveis configuradas:

```
Workspace variables
┌──────────────────────────────────────────────┬─────────────────┬───────────┐
│ Key                                          │ Value           │ Category  │
├──────────────────────────────────────────────┼─────────────────┼───────────┤
│ enable_grafana_agent                         │ true            │ Terraform │
│ grafana_cloud_prometheus_url                 │ https://prom... │ Terraform │
│ grafana_cloud_prometheus_username            │ 123456          │ Terraform │
│ grafana_cloud_prometheus_api_key             │ ••••••••••••    │ Terraform │ ← Sensitive
│ grafana_cloud_loki_url                       │ https://logs... │ Terraform │ (opcional)
│ grafana_cloud_loki_username                  │ 123456          │ Terraform │ (opcional)
│ grafana_cloud_loki_api_key                   │ ••••••••••••    │ Terraform │ (opcional)
└──────────────────────────────────────────────┴─────────────────┴───────────┘
```

---

## 🚀 PASSO 8: Aplicar Terraform

Agora você pode aplicar as mudanças!

### **8.1: No seu terminal:**

```bash
cd C:\Projects\tc-cloudgames-solution\infrastructure\terraform\foundation
terraform plan
```

Verifique se o plan mostra o módulo `grafana_agent` sendo criado:

```
Plan: 3 to add, 0 to change, 0 to destroy.

module.grafana_agent[0].kubernetes_namespace.grafana_agent will be created
module.grafana_agent[0].kubernetes_secret.grafana_cloud_credentials will be created
module.grafana_agent[0].helm_release.grafana_agent will be created
```

### **8.2: Aplicar:**

```bash
terraform apply
```

Digite `yes` quando solicitado.

---

## 🔍 PASSO 9: Verificar se Está Funcionando

### **9.1: Verificar Pods do Grafana Agent**

```bash
# Conectar ao AKS
az aks get-credentials --resource-group tc-cloudgames-solution-dev-rg --name tc-cloudgames-dev-cr8n-aks

# Verificar pods
kubectl get pods -n grafana-agent

# Deve mostrar algo como:
# NAME                   READY   STATUS    RESTARTS   AGE
# grafana-agent-xxxxx    1/1     Running   0          2m

# Ver logs
kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent --tail=50
```

### **9.2: Verificar Métricas no Grafana Cloud**

1. Acesse seu Grafana Cloud: `https://yourcompany.grafana.net`
2. No menu lateral, clique em **"Explore"**
3. No dropdown de data source, selecione **"Prometheus"**
4. Digite esta query:

```promql
up{job="kubelet"}
```

5. Clique em **"Run query"**
6. Você deve ver métricas dos nodes do seu cluster AKS! 🎉

### **9.3: Queries de Teste**

Experimente estas queries para ver diferentes métricas:

```promql
# Ver todos os nodes
up{job="kubelet"}

# CPU dos containers
container_cpu_usage_seconds_total

# Memória dos pods
container_memory_usage_bytes

# Número de pods por namespace
kube_pod_info
```

---

## 🎁 PASSO 10: Importar Dashboards Prontos

1. No Grafana Cloud, clique em **"Dashboards"** no menu lateral
2. Clique em **"New"** → **"Import"**
3. Cole um dos IDs abaixo e clique em **"Load"**:

| Dashboard | ID | Descrição |
|-----------|-----|-----------|
| **Kubernetes Cluster Monitoring** | `7249` | Overview completo do cluster |
| **Kubernetes Pod Monitoring** | `6417` | Métricas detalhadas de pods |
| **Node Exporter Full** | `1860` | Métricas de nodes |

4. Selecione o data source **"Prometheus"**
5. Clique em **"Import"**

Pronto! Você terá dashboards lindos mostrando todas as métricas do seu AKS! 📊✨

---

## 🆘 Troubleshooting

### **Problema: Não vejo métricas no Grafana Cloud**

1. Verifique se o Grafana Agent está rodando:
   ```bash
   kubectl get pods -n grafana-agent
   ```

2. Verifique os logs do agent:
   ```bash
   kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent
   ```

3. Verifique se as credenciais estão corretas:
   - URL Prometheus sem `/api/prom/push`
   - Username é o Instance ID (número)
   - API Key começa com `glc_`

### **Problema: API Key inválida**

1. Gere uma nova API Key no Grafana Cloud
2. Atualize a variável `grafana_cloud_prometheus_api_key` no Terraform Cloud
3. Execute `terraform apply` novamente

---

## 🎯 Checklist Final

- [ ] Obtive Prometheus URL do Grafana Cloud
- [ ] Obtive Username (Instance ID)
- [ ] Criei API Key com role MetricsPublisher
- [ ] Adicionei 4 variáveis no Terraform Cloud:
  - [ ] `enable_grafana_agent` = `true` (HCL enabled)
  - [ ] `grafana_cloud_prometheus_url`
  - [ ] `grafana_cloud_prometheus_username`
  - [ ] `grafana_cloud_prometheus_api_key` (SENSITIVE)
- [ ] Executei `terraform apply`
- [ ] Verifiquei pods: `kubectl get pods -n grafana-agent`
- [ ] Verifiquei métricas no Grafana Cloud: query `up{job="kubelet"}`
- [ ] Importei dashboards (IDs: 7249, 6417, 1860)

---

## 🎊 Parabéns!

Seu AKS agora está enviando métricas para o Grafana Cloud automaticamente! 

Você tem:
- ✅ Monitoramento completo de Kubernetes
- ✅ Métricas de nodes, pods e containers
- ✅ Dashboards prontos e customizáveis
- ✅ Tudo integrado no mesmo Grafana Cloud

🚀 **Enjoy your observability!** 🚀
