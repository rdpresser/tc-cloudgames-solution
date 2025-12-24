# =============================================================================
# NGINX Ingress Controller Variables
# =============================================================================

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "nginx_namespace" {
  description = "Kubernetes namespace for NGINX Ingress Controller"
  type        = string
  default     = "ingress-nginx"
}

variable "nginx_chart_version" {
  description = "Helm chart version for NGINX Ingress Controller"
  type        = string
  default     = "4.11.3"
}

variable "replica_count" {
  description = "Number of NGINX Ingress Controller replicas"
  type        = number
  default     = 2
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "enable_service_monitor" {
  description = "Enable ServiceMonitor for Prometheus Operator"
  type        = bool
  default     = false
}

variable "enable_pdb" {
  description = "Enable PodDisruptionBudget"
  type        = bool
  default     = true
}

variable "enable_default_backend" {
  description = "Enable default backend"
  type        = bool
  default     = true
}

variable "load_balancer_ip" {
  description = "Static IP address for the Load Balancer (optional)"
  type        = string
  default     = null
}

variable "node_resource_group" {
  description = "Node resource group name (MC_xxx) for static IP allocation"
  type        = string
  default     = null
}

variable "cpu_request" {
  description = "CPU request for NGINX Ingress Controller"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request for NGINX Ingress Controller"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit for NGINX Ingress Controller"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for NGINX Ingress Controller"
  type        = string
  default     = "256Mi"
}
