# 📊 AKS → Grafana Cloud Integration (Consolidated Guide)

This is the **single source of truth** for integrating your AKS cluster with Grafana Cloud using Grafana Agent. It consolidates and replaces:
- `GRAFANA_CLOUD_CREDENTIALS_GUIDE.md`
- `GRAFANA_CLOUD_SETUP.md`
- Any other fragmented documentation

## Table of Contents

- [Why Azure Monitor + Grafana Agent](#why-azure-monitor--grafana-agent)
- [Obtain Grafana Cloud Credentials](#obtain-grafana-cloud-credentials)
- [Terraform Variables](#terraform-variables)
- [Terraform Setup](#terraform-setup)
- [Apply & Verify](#apply--verify)
- [Configure .NET Applications](#configure-net-applications)
- [Kubernetes Annotations](#kubernetes-annotations)
- [Dashboards](#dashboards)
- [Troubleshooting](#troubleshooting)
- [Metrics Collected](#metrics-collected)

---

## Why Azure Monitor + Grafana Agent

You need both for complete observability:

| Solution | Azure Monitor Data Source | Grafana Agent |
|----------|---------------------------|---------------|
| **Coverage** | Azure infrastructure (VMs, Disks, PaaS, Activity Logs) | Kubernetes + Application metrics |
| **Cost** | Pay per GB ingested | Included in Grafana Cloud |
| **Flexibility** | Azure-only | Any Prometheus exporter |
| **Custom Metrics** | Complex setup | Simple (pod annotations) |
| **Vendor Lock** | Azure | Multi-cloud |

**Recommendation**: Use **Grafana Agent** + **Grafana Cloud** for Kubernetes/Apps metrics, and keep **Azure Monitor Data Source** in Grafana for Azure infrastructure metrics.

---

## Obtain Grafana Cloud Credentials

### Step 1: Access Grafana Cloud

1. Go to: **https://grafana.com**
2. Click **"Sign In"** and log in
3. Select your stack (e.g., `yourcompany.grafana.net`)

### Step 2: Get Prometheus Details

**Option A: Via Connections (Recommended)**
1. Left sidebar → **Connections**
2. Click **"Add new connection"**
3. Search for **"Prometheus"**
4. Click **"Via Grafana Agent, Prometheus and OpenTelemetry"**

**Option B: Via Administration**
1. Left sidebar → **Administration** → **Settings**
2. Scroll to **Grafana Cloud** section

You will see:
```
Remote Write Endpoint: https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
Remote Write User: 123456
```

**Copy these values:**
- **Prometheus URL** (base, WITHOUT `/api/prom/push`): `https://prometheus-prod-XX-XX-X.grafana.net`
- **Username** (Instance ID): `123456`

### Step 3: Generate API Key

1. Left sidebar → **Administration** → **API Keys**
2. Click **"Create API Key"** or **"Add API Key"**
3. Fill in:
   - **Display Name**: `aks-metrics-writer`
   - **Role**: `MetricsPublisher`
   - **Time to Live**: `1 year` or `Never expire`
4. Click **"Create"**
5. **IMMEDIATELY COPY THE KEY** (starts with `glc_...`)

⚠️ **WARNING**: You will only see the API Key once! Store it securely.

### Optional: Loki (Logs)

If you want to send logs:
- **Loki URL**: `https://logs-prod-XX.grafana.net`
- **Username**: Same Instance ID
- **API Key**: Same key or create one with `LogsPublisher` role

### Summary of Credentials

| Credential | Example Value | Sensitive? |
|------------|---------------|------------|
| `grafana_cloud_prometheus_url` | `https://prometheus-prod-01-eu-west-0.grafana.net` | No |
| `grafana_cloud_prometheus_username` | `123456` | No |
| `grafana_cloud_prometheus_api_key` | `glc_eyJvIjoiMTIzNDU2...` | **YES** |
| `grafana_cloud_loki_url` | `https://logs-prod-eu-west-0.grafana.net` | No |
| `grafana_cloud_loki_username` | `123456` | No |
| `grafana_cloud_loki_api_key` | `glc_eyJvIjoiMTIzNDU2...` | **YES** |

---

## Terraform Variables

### In Terraform Cloud

1. Go to: https://app.terraform.io
2. Organization: `rdpresser_tccloudgames_fiap`
3. Workspace: `tc-cloudgames-foundation-dev`
4. Click **"Variables"**
5. Add these **Terraform variables**:

| Variable Name | Category | Sensitive? |
|---------------|----------|------------|
| `enable_grafana_agent` | Terraform (HCL=true) | No |
| `grafana_cloud_prometheus_url` | Terraform | No |
| `grafana_cloud_prometheus_username` | Terraform | No |
| `grafana_cloud_prometheus_api_key` | Terraform | **YES** |
| `grafana_cloud_loki_url` | Terraform | No |
| `grafana_cloud_loki_username` | Terraform | No |
| `grafana_cloud_loki_api_key` | Terraform | **YES** |

---

## Terraform Setup

### Module Variables (variables.tf)

```hcl
variable "enable_grafana_agent" {
  description = "Enable Grafana Agent deployment"
  type        = bool
  default     = false
}

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write URL (base, without /api/prom/push)"
  type        = string
  default     = ""
}

variable "grafana_cloud_prometheus_username" {
  description = "Grafana Cloud Prometheus username (Instance ID)"
  type        = string
  default     = ""
}

variable "grafana_cloud_prometheus_api_key" {
  description = "Grafana Cloud Prometheus API key"
  type        = string
  sensitive   = true
  default     = ""
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

### Module Usage (main.tf)

```hcl
module "grafana_agent" {
  source = "../modules/grafana_agent"
  count  = var.enable_grafana_agent ? 1 : 0

  cluster_name        = module.aks.cluster_name
  resource_group_name = module.resource_group.name

  grafana_cloud_prometheus_url      = var.grafana_cloud_prometheus_url
  grafana_cloud_prometheus_username = var.grafana_cloud_prometheus_username
  grafana_cloud_prometheus_api_key  = var.grafana_cloud_prometheus_api_key

  grafana_cloud_loki_url      = var.grafana_cloud_loki_url
  grafana_cloud_loki_username = var.grafana_cloud_loki_username
  grafana_cloud_loki_api_key  = var.grafana_cloud_loki_api_key

  labels = local.common_tags

  depends_on = [module.aks]
}
```

### Outputs (outputs.tf)

```hcl
output "grafana_agent_info" {
  description = "Grafana Agent deployment details"
  value = var.enable_grafana_agent ? {
    namespace            = module.grafana_agent[0].namespace
    helm_release_name    = module.grafana_agent[0].helm_release_name
    helm_release_version = module.grafana_agent[0].helm_release_version
    prometheus_url       = module.grafana_agent[0].grafana_cloud_prometheus_url
  } : null
}
```

---

## Apply & Verify

### Apply Terraform

```bash
terraform plan
terraform apply
```

### Verify in AKS

```bash
# Connect to AKS
az aks get-credentials --resource-group tc-cloudgames-solution-dev-rg --name tc-cloudgames-dev-cr8n-aks

# Check Grafana Agent pods
kubectl get pods -n grafana-agent

# Check logs
kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent --tail=100
```

### Verify in Grafana Cloud

1. Go to your Grafana Cloud instance
2. Navigate to **Explore**
3. Select **Prometheus** data source
4. Run test queries:

```promql
# Check if data is arriving
up{job="kubelet"}

# Kubernetes pod info
kube_pod_info

# Container CPU usage
container_cpu_usage_seconds_total

# Container memory usage
container_memory_usage_bytes
```

---

## Configure .NET Applications

To expose metrics from your .NET applications so Grafana Agent can scrape them:

### Step 1: Install NuGet Package

```bash
dotnet add package prometheus-net.AspNetCore
```

### Step 2: Configure Program.cs

```csharp
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// Add your services...
builder.Services.AddControllers();

var app = builder.Build();

// Enable Prometheus metrics
app.UseMetricServer();     // Exposes /metrics endpoint
app.UseHttpMetrics();       // Auto-collects HTTP request metrics

app.MapControllers();
app.Run();
```

### Step 3: Add Custom Metrics (Optional)

```csharp
using Prometheus;

public class OrderService
{
    // Counter: increments only
    private static readonly Counter OrdersCreated = Metrics
        .CreateCounter("orders_created_total", "Total orders created",
            new CounterConfiguration { LabelNames = new[] { "status" } });

    // Gauge: can go up or down
    private static readonly Gauge ActiveOrders = Metrics
        .CreateGauge("orders_active_count", "Currently active orders");

    // Histogram: measures distributions
    private static readonly Histogram OrderProcessingTime = Metrics
        .CreateHistogram("order_processing_seconds", "Order processing time",
            new HistogramConfiguration { Buckets = Histogram.LinearBuckets(0.1, 0.1, 10) });

    public async Task<Order> CreateOrder(OrderRequest request)
    {
        using (OrderProcessingTime.NewTimer())
        {
            ActiveOrders.Inc();
            try
            {
                var order = await ProcessOrder(request);
                OrdersCreated.WithLabels("success").Inc();
                return order;
            }
            catch
            {
                OrdersCreated.WithLabels("failed").Inc();
                throw;
            }
            finally
            {
                ActiveOrders.Dec();
            }
        }
    }
}
```

### Step 4: Test Locally

```bash
# Run your application
dotnet run

# Check metrics endpoint
curl http://localhost:5000/metrics
```

You should see output like:
```
# HELP http_requests_received_total Total HTTP requests received
# TYPE http_requests_received_total counter
http_requests_received_total{method="GET",code="200"} 42
...
```

---

## Kubernetes Annotations

For Grafana Agent to scrape your pods, add these annotations to your Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-api
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"    # Enable scraping
        prometheus.io/port: "8080"       # Port where /metrics is exposed
        prometheus.io/path: "/metrics"   # Path to metrics endpoint
    spec:
      containers:
      - name: users-api
        image: tccloudgamesdevcr8nacr.azurecr.io/users-api:latest
        ports:
        - containerPort: 8080
```

### Example: Full Deployment with Prometheus Annotations

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: games-api
  namespace: cloudgames
  labels:
    app: games-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: games-api
  template:
    metadata:
      labels:
        app: games-api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: games-api
        image: tccloudgamesdevcr8nacr.azurecr.io/games-api:latest
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
```

---

## Dashboards

Import these recommended dashboards in Grafana Cloud:

| Dashboard | ID | Description |
|-----------|----|-------------|
| Kubernetes Cluster Monitoring | `7249` | Overall cluster health |
| Kubernetes Pod Monitoring | `6417` | Pod-level metrics |
| Node Exporter Full | `1860` | Node-level metrics |
| .NET Core | `10427` | ASP.NET Core metrics |

### How to Import

1. Go to **Dashboards** → **Import**
2. Enter the dashboard ID
3. Click **Load**
4. Select your Prometheus data source
5. Click **Import**

---

## Troubleshooting

### No metrics appearing in Grafana Cloud

1. **Check Agent pods are running:**
   ```bash
   kubectl get pods -n grafana-agent
   ```

2. **Check Agent logs for errors:**
   ```bash
   kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent --tail=100
   ```

3. **Verify credentials:**
   - Prometheus URL should NOT include `/api/prom/push`
   - Username is the Instance ID (numeric)
   - API Key starts with `glc_`

### Invalid API Key error

1. Generate a new API Key in Grafana Cloud
2. Update `grafana_cloud_prometheus_api_key` in Terraform Cloud
3. Run `terraform apply`

### Application metrics not appearing

1. **Check pod annotations:**
   ```bash
   kubectl get pod <pod-name> -o yaml | grep -A5 annotations
   ```

2. **Verify /metrics endpoint is accessible:**
   ```bash
   kubectl port-forward pod/<pod-name> 8080:8080
   curl http://localhost:8080/metrics
   ```

3. **Check pod labels match service discovery:**
   ```bash
   kubectl get pods --show-labels
   ```

### Agent high memory usage

Reduce scrape targets or increase resource limits in the Helm values.

---

## Metrics Collected

### Automatically by Grafana Agent

| Source | Metrics |
|--------|---------|
| **Kubelet** | Node CPU, memory, disk, network, conditions |
| **cAdvisor** | Container CPU, memory, network I/O, disk I/O |
| **Kube State Metrics** | Deployments, Pods, Services status, ReplicaSets, DaemonSets |
| **Annotated Pods** | Any pod with `prometheus.io/scrape: "true"` |

### From .NET Applications (with prometheus-net)

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_received_total` | Counter | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | HTTP request latency |
| `http_requests_in_progress` | Gauge | Current in-flight requests |
| `dotnet_total_memory_bytes` | Gauge | .NET memory usage |
| `dotnet_gc_collection_count_total` | Counter | GC collections |
| `process_cpu_seconds_total` | Counter | CPU time consumed |

---

## Summary

| Component | Purpose |
|-----------|---------|
| **Azure Monitor DS** | Azure infrastructure metrics |
| **Grafana Agent** | Kubernetes + application metrics |
| **Grafana Cloud** | Visualization, dashboards, alerting |
| **prometheus-net** | .NET application metrics |

This consolidated guide is the single source of truth. Keep it updated as configurations change.
