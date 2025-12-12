# 🔑 Guide: Obtaining Grafana Cloud Credentials

## 📋 Complete Step-by-Step

### **STEP 1: Access Grafana Cloud**

1. Open your browser
2. Go to: **https://grafana.com**
3. Click **"Sign In"** in the upper right corner
4. Log in with your credentials

---

### **STEP 2: Select Your Stack**

After logging in, you will see your available stacks:

```
📊 My Stacks
┌─────────────────────────────────────┐
│  yourcompany.grafana.net           │  ← Click here
│  Status: Active                     │
│  Region: EU West                    │
└─────────────────────────────────────┘
```

**Action**: Click on your stack (e.g., `yourcompany.grafana.net`)

---

### **STEP 3: Access Prometheus Settings**

#### **Option A: Via "Connections" (Recommended)**

1. In the left sidebar menu, click **"Connections"**
2. Click **"Add new connection"** (blue button at the top)
3. In the search box, type: **"Prometheus"**
4. Click **"Prometheus"** or **"Hosted Prometheus metrics"**
5. Click the **"Via Grafana Agent, Prometheus and OpenTelemetry"** button

#### **Option B: Via "Administration"**

1. In the left sidebar menu, click **"Administration"** (gear icon)
2. Click **"Settings"**
3. Scroll down to the **"Grafana Cloud"** section
4. You will see something like this:

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

### **STEP 4: Copy Prometheus URL and Username**

You will see a screen like this:

```
┌─────────────────────────────────────────────────────────┐
│  Configure Prometheus Remote Write                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Remote Write Endpoint:                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │ https://prometheus-prod-01-eu-west-0.grafana.net   │ │ ← COPY THIS (WITHOUT /api/prom/push)
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Username / Instance ID:                                │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 123456                                              │ │ ← COPY THIS
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**⚠️ IMPORTANT**: Copy only the BASE Prometheus URL (without `/api/prom/push` at the end):
- ✅ CORRECT: `https://prometheus-prod-01-eu-west-0.grafana.net`
- ❌ WRONG: `https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push`

**Note down:**
- **Prometheus URL**: `https://prometheus-prod-XX-XX-X.grafana.net` (your URL will be different)
- **Username**: `123456` (your Instance ID will be different)

---

### **STEP 5: Generate API Key**

Now you need to create an API Key for authentication.

#### **5.1: Access API Keys Management**

1. In the left sidebar menu, click your **organization icon** (usually at the top)
2. Click **"Administration"** → **"API Keys"**

**OR**

1. Click your avatar/name in the upper right corner
2. Click **"My Account"** or **"Organization Settings"**
3. Click **"API Keys"** in the sidebar menu

#### **5.2: Create New API Key**

1. Click the **"Create API Key"** or **"Add API Key"** button
2. Fill in the fields:

```
┌─────────────────────────────────────────────────────────┐
│  Create API Key                                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Display Name:                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ aks-metrics-writer                                 │ │ ← Descriptive name
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Role:                                                   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ MetricsPublisher                        [▼]        │ │ ← Select this role
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  Time to Live:                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 1 year                                  [▼]        │ │ ← Or "Never expire"
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  [Cancel]                           [Add API Key] ───┐  │
└──────────────────────────────────────────────────────│───┘
                                                       └────► Click here
```

3. Click **"Add API Key"** or **"Create"**

#### **5.3: Copy the API Key**

**⚠️ WARNING: YOU WILL ONLY SEE THE API KEY ONCE!**

After creating it, you will see a screen like this:

```
# 🔑 Guide: Obtaining Grafana Cloud Credentials

This document has been consolidated into the single source of truth:

`infrastructure/terraform/modules/grafana_agent/README.md`

Jump directly to the credentials section:
- Consolidated Guide → [Obtain Grafana Cloud Credentials](../modules/grafana_agent/README.md#credentials)

Reason for change:
- Avoid duplicated and overlapping instructions
- Keep one definitive, English-only guide with anchors

If you prefer a quick path:
- Prometheus URL (base, no `/api/prom/push`), Username (Instance ID), API Key (`glc_...` with MetricsPublisher)
- Optional Loki URL/Username/API Key for logs
---

For complete, up-to-date instructions, see:

- `infrastructure/terraform/modules/grafana_agent/README.md#credentials`

This stub remains only to point to the consolidated documentation.

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
