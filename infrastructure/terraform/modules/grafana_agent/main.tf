# =============================================================================
# Grafana Agent (Flow mode) Installation via Helm
# =============================================================================
# Clean refactor for Helm provider v3: all overrides passed as a single values YAML.
# This module assumes providers are configured by the parent/root module.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.52" # Latest 4.x
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1" # Latest 3.x
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38" # Latest 2.x
    }
  }
}

# =============================================================================
# Data Source: Ensure AKS cluster exists before deploying agent
# =============================================================================
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

# =============================================================================
# Secret holding Grafana Cloud credentials (optional Loki keys included if set)
# =============================================================================
locals {
  grafana_cloud_secret_data = merge(
    {
      prometheus_username = var.grafana_cloud_prometheus_username
      prometheus_api_key  = var.grafana_cloud_prometheus_api_key
    },
    var.grafana_cloud_loki_url != "" ? {
      loki_username = var.grafana_cloud_loki_username
      loki_api_key  = var.grafana_cloud_loki_api_key
    } : {}
  )
}

resource "kubernetes_namespace" "grafana_agent" {
  metadata {
    name = "grafana-agent"
    labels = {
      app = "grafana-agent"
    }
  }
}

resource "kubernetes_secret" "grafana_cloud_credentials" {
  metadata {
    name      = "grafana-cloud-credentials"
    namespace = kubernetes_namespace.grafana_agent.metadata[0].name
  }
  data = local.grafana_cloud_secret_data
  type = "Opaque"
}

# =============================================================================
# Helm values for Grafana Agent (Flow mode)
# =============================================================================
locals {
  grafana_agent_values = yamlencode({
    agent = {
      mode = "flow"
      configMap = {
        content = <<-EOT
// =============================================================================
// Grafana Agent Flow Configuration (metrics only)
// =============================================================================

prometheus.remote_write "grafana_cloud" {
  endpoint {
    url = "${var.grafana_cloud_prometheus_url}/api/prom/push"
    basic_auth {
      username = "${var.grafana_cloud_prometheus_username}"
      password = "${var.grafana_cloud_prometheus_api_key}"
    }
  }
}

// Service discovery
discovery.kubernetes "pods"     { role = "pod" }
discovery.kubernetes "nodes"    { role = "node" }
discovery.kubernetes "services" { role = "service" }
discovery.kubernetes "endpoints" { role = "endpoints" }

// Kubelet metrics
prometheus.scrape "kubelet" {
  targets    = discovery.kubernetes.nodes.targets
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  scheme     = "https"
  bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  tls_config { insecure_skip_verify = true }
}

// cAdvisor metrics
prometheus.scrape "cadvisor" {
  targets    = discovery.kubernetes.nodes.targets
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  scheme     = "https"
  metrics_path = "/metrics/cadvisor"
  bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  tls_config { insecure_skip_verify = true }
}

// kube-state-metrics (if installed)
prometheus.scrape "kube_state_metrics" {
  targets    = discovery.kubernetes.services.targets
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  relabel_rules {
    source_labels = ["__meta_kubernetes_service_name"]
    regex         = "kube-state-metrics"
    action        = "keep"
  }
}

// Annotated pods
prometheus.scrape "pods" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  relabel_rules { source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"], regex = "true", action = "keep" }
  relabel_rules { source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_port"], target_label = "__address__", regex = "(.+)", replacement = "$1:$1" }
  relabel_rules { source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"], target_label = "__metrics_path__", regex = "(.+)", action = "replace" }
  relabel_rules { action = "labelmap", regex = "__meta_kubernetes_pod_label_(.+)" }
  relabel_rules { source_labels = ["__meta_kubernetes_namespace"], target_label = "namespace" }
  relabel_rules { source_labels = ["__meta_kubernetes_pod_name"], target_label = "pod" }
}

// Uncomment to enable Loki logs collection
/*
loki.write "grafana_cloud" {
  endpoint {
    url = "${var.grafana_cloud_loki_url}/loki/api/v1/push"
    basic_auth {
      username = "${var.grafana_cloud_loki_username}"
      password = "${var.grafana_cloud_loki_api_key}"
    }
  }
}

loki.source.kubernetes "pods" {
  targets    = discovery.kubernetes.pods.targets
  forward_to = [loki.write.grafana_cloud.receiver]
}
*/
EOT
      }
    }
    controller = {
      type = "daemonset"
      resources = {
        limits   = { cpu = "500m", memory = "512Mi" }
        requests = { cpu = "100m", memory = "256Mi" }
      }
      labels = var.labels
    }
    serviceAccount = { create = true }
  })
}

# =============================================================================
# Helm Release: Grafana Agent
# =============================================================================
resource "helm_release" "grafana_agent" {
  name       = "grafana-agent"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana-agent"
  version    = var.grafana_agent_chart_version
  namespace  = kubernetes_namespace.grafana_agent.metadata[0].name

  values = [local.grafana_agent_values]

  depends_on = [
    kubernetes_namespace.grafana_agent,
    kubernetes_secret.grafana_cloud_credentials,
    data.azurerm_kubernetes_cluster.aks
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes
}
