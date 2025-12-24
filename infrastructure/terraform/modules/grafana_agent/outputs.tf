# =============================================================================
# Grafana Agent Module Outputs
# =============================================================================

output "namespace" {
  description = "Namespace where Grafana Agent is deployed"
  value       = kubernetes_namespace_v1.grafana_agent.metadata[0].name
}

output "helm_release_name" {
  description = "Name of the Grafana Agent Helm release"
  value       = helm_release.grafana_agent.name
}

output "helm_release_version" {
  description = "Version of the Grafana Agent Helm chart deployed"
  value       = helm_release.grafana_agent.version
}

output "helm_release_status" {
  description = "Status of the Grafana Agent Helm release"
  value       = helm_release.grafana_agent.status
}

output "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus URL configured"
  value       = var.grafana_cloud_prometheus_url
}

output "grafana_cloud_loki_url" {
  description = "Grafana Cloud Loki URL configured"
  value       = var.grafana_cloud_loki_url
}
