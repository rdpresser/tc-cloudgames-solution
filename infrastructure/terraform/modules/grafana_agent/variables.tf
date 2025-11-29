# =============================================================================
# Grafana Agent Module Variables
# =============================================================================

variable "cluster_name" {
  description = "Name of the AKS cluster where Grafana Agent will be installed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the AKS cluster"
  type        = string
}

# =============================================================================
# Grafana Cloud Configuration
# =============================================================================

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write URL (e.g., https://prometheus-prod-01-eu-west-0.grafana.net)"
  type        = string
}

variable "grafana_cloud_prometheus_username" {
  description = "Grafana Cloud Prometheus username (usually your instance ID)"
  type        = string
}

variable "grafana_cloud_prometheus_api_key" {
  description = "Grafana Cloud Prometheus API key"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_loki_url" {
  description = "Grafana Cloud Loki URL (e.g., https://logs-prod-eu-west-0.grafana.net)"
  type        = string
  default     = ""
}

variable "grafana_cloud_loki_username" {
  description = "Grafana Cloud Loki username (usually your instance ID)"
  type        = string
  default     = ""
}

variable "grafana_cloud_loki_api_key" {
  description = "Grafana Cloud Loki API key"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Grafana Agent Configuration
# =============================================================================

variable "grafana_agent_chart_version" {
  description = "Version of the Grafana Agent Helm chart"
  type        = string
  default     = "0.46.0" # Latest stable as of Nov 2024
}

variable "labels" {
  description = "Additional labels to apply to Grafana Agent resources"
  type        = map(string)
  default     = {}
}
