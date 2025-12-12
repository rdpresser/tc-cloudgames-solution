# 📊 AKS → Grafana Cloud Integration (Consolidated Guide)

This is the single, canonical guide for integrating your AKS cluster with Grafana Cloud using Grafana Agent. It merges and replaces:
- `GRAFANA_CLOUD_CREDENTIALS_GUIDE.md` (credentials)
- `RESUMO_EXECUTIVO.md` (executive summary)
- `GRAFANA_CLOUD_SETUP.md` (setup)

Use the anchors below to jump to sections:
- Executive Summary: [Why Azure Monitor + Grafana Agent] (#executive-summary)
- Get Credentials: [Prometheus/Loki URL, Username, API Key] (#credentials)
- Terraform Variables: [Workspace variable names] (#terraform-variables)
- Terraform Setup: [Module wiring, providers, outputs] (#terraform-setup)
- Verification: [Pods, logs, Grafana queries] (#verification)
- Dashboards: [Import recommended dashboards] (#dashboards)
- Troubleshooting: [Common issues and fixes] (#troubleshooting)

---

## 🎯 Why Azure Monitor + Grafana Agent {#executive-summary}

You need both:
- Azure Monitor Data Source → Infra Azure metrics (VMs, Disks, PaaS, Activity Logs)
- Grafana Agent in AKS → Kubernetes + Application metrics (kubelet, cAdvisor, Kube State, Prometheus exporters)

Grafana Agent covers:
- Kubernetes metrics (nodes, pods, containers)
- Application metrics (.NET + `prometheus-net`)
- Optional: Logs (Loki) and Traces (Tempo)

---

## 🔑 Obtain Grafana Cloud Credentials {#credentials}

Prometheus (metrics):
- URL (base, without `/api/prom/push`), e.g. `https://prometheus-prod-XX-XX-X.grafana.net`
- Username: Instance ID (numeric)
- API Key: Starts with `glc_` (Role: MetricsPublisher)

Optional Loki (logs):
- URL: `https://logs-prod-XX.grafana.net`
- Username: same Instance ID
- API Key: `glc_...` (Role: LogsPublisher or reuse Prometheus key)

Steps in Grafana Cloud:
1. Sign in → select your stack (e.g., `yourcompany.grafana.net`)
2. Connections → Prometheus → copy Remote Write details (URL base + user)
3. Administration → API Keys → create key `aks-metrics-writer` with role `MetricsPublisher`

---

## 🧩 Terraform Variables (Terraform Cloud) {#terraform-variables}

Set these workspace variables (Terraform variable category):
- `enable_grafana_agent` (HCL=true) = `true`
- `grafana_cloud_prometheus_url` (string)
- `grafana_cloud_prometheus_username` (string)
- `grafana_cloud_prometheus_api_key` (string, Sensitive=true)
Optional (Loki):
- `grafana_cloud_loki_url` (string)
- `grafana_cloud_loki_username` (string)
- `grafana_cloud_loki_api_key` (string, Sensitive=true)

---

## 🏗️ Terraform Setup {#terraform-setup}

Providers (example):
```
terraform {
  required_providers {
    azurerm    = "~> 4.0"
    helm       = "~> 2.12"
    kubernetes = "~> 2.25"
  }
}
```

Module wiring (example):
```
module "grafana_agent" {
  source = "../modules/grafana_agent"

  grafana_cloud_prometheus_url      = var.grafana_cloud_prometheus_url
  grafana_cloud_prometheus_username = var.grafana_cloud_prometheus_username
  grafana_cloud_prometheus_api_key  = var.grafana_cloud_prometheus_api_key

  grafana_cloud_loki_url      = var.grafana_cloud_loki_url
  grafana_cloud_loki_username = var.grafana_cloud_loki_username
  grafana_cloud_loki_api_key  = var.grafana_cloud_loki_api_key
}
```

Outputs (example):
```
output "grafana_agent_info" {
  description = "Grafana Agent deployment details"
  value = {
    namespace            = module.grafana_agent.namespace
    helm_release_name    = module.grafana_agent.helm_release_name
    helm_release_version = module.grafana_agent.helm_release_version
    prometheus_url       = module.grafana_agent.grafana_cloud_prometheus_url
  }
}
```

---

## ✅ Apply & Verify {#verification}

Apply:
```
terraform plan
terraform apply
```

Verify in AKS:
```
az aks get-credentials --resource-group <rg> --name <aks>
kubectl get pods -n grafana-agent
kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent --tail=50
```

Verify in Grafana Cloud:
- Explore → Prometheus, run `up{job="kubelet"}`
- Try: `container_cpu_usage_seconds_total`, `container_memory_usage_bytes`, `kube_pod_info`

---

## 📊 Dashboards {#dashboards}

Import recommended dashboards:
- Kubernetes Cluster Monitoring (ID 7249)
- Kubernetes Pod Monitoring (ID 6417)
- Node Exporter Full (ID 1860)

---

## 🆘 Troubleshooting {#troubleshooting}

No metrics appearing:
- Check Agent pods/logs in `grafana-agent` namespace
- Validate Prometheus URL (without `/api/prom/push`), username (Instance ID), and API Key (`glc_...`)

Invalid API Key:
- Regenerate in Grafana Cloud → update Terraform Cloud variable → `terraform apply`

LoadBalancer / network issues (if applicable):
- Validate cluster DNS / egress → retry apply, check Helm release status

---

## ✅ Summary

- Azure Monitor DS → Azure infra metrics
- Grafana Agent → Kubernetes + application metrics
- Credentials via Grafana Cloud → Terraform variables → Helm deploy via Terraform
- Verified via AKS logs and Grafana queries

This consolidated README replaces prior fragmented docs. Keep this as the single source of truth.
