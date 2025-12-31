variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "tc-cloudgames"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "azure_resource_group_location" {
  description = "Location for the resource group"
  type        = string
  default     = "eastus2"

  validation {
    condition = contains([
      "eastus", "eastus2", "westus", "westus2", "westus3",
      "centralus", "southcentralus", "northcentralus", "westcentralus",
      "canadacentral", "canadaeast", "brazilsouth",
      "northeurope", "westeurope", "francecentral", "germanywestcentral", "norwayeast",
      "uksouth", "ukwest", "switzerlandnorth", "swedencentral",
      "eastasia", "southeastasia", "japaneast", "japanwest", "koreacentral", "australiaeast", "australiasoutheast"
    ], var.azure_resource_group_location)
    error_message = "The azure_resource_group_location must be a valid Azure region."
  }
}

# =============================================================================
# Variables from Terraform Cloud workspace
# =============================================================================
# PostgreSQL administrator username
variable "postgres_admin_login" {
  type        = string
  description = "PostgreSQL administrator username"
}

# PostgreSQL administrator password
variable "postgres_admin_password" {
  type        = string
  description = "PostgreSQL administrator password"
  sensitive   = true
}

# PostgreSQL SKU (compute tier/size). Defaults to B_Standard_B2s for cost optimization.
variable "postgres_sku" {
  type        = string
  description = "PostgreSQL Flexible Server SKU (e.g., B_Standard_B1ms, B_Standard_B2s, GP_Standard_D2s_v3)"
  default     = "B_Standard_B2s"
}

# PostgreSQL max_connections parameter
# B_Standard_B2s supports up to 429 connections
# Default: 250 (allows 3 services × 4 pods × 15 connections + admin/monitoring)
variable "postgres_max_connections" {
  type        = number
  description = "Maximum concurrent connections to PostgreSQL (default 250 for B2s SKU)"
  default     = 300

  validation {
    condition     = var.postgres_max_connections >= 50 && var.postgres_max_connections <= 5000
    error_message = "postgres_max_connections must be between 50 and 5000"
  }
}

variable "db_max_pool_size" {
  description = "Application DB max pool size"
  type        = number
  default     = 5
}

variable "db_min_pool_size" {
  description = "Application DB min pool size"
  type        = number
  default     = 0
}
# =============================================================================
# RBAC Access Control Variables (Object IDs for Key Vault permissions)
# =============================================================================

variable "app_object_id" {
  type        = string
  description = "Object ID of the application service principal (Terraform Cloud/GitHub Actions) that needs Key Vault access"
}

variable "user_object_id" {
  type        = string
  description = "Object ID of the Azure AD user that needs Key Vault access for management"
  default     = null
}

variable "github_actions_object_id" {
  type        = string
  description = "Object ID of the GitHub Actions service principal for CI/CD pipelines"
  default     = null
}

# =============================================================================
# Container Apps Key Vault Integration Control
# =============================================================================

variable "use_keyvault_secrets" {
  type        = bool
  description = "Enable Key Vault secrets gradually to avoid RBAC propagation issues. Deploy ACR first (false), then enable secrets (true) after RBAC propagates."
  default     = false
}

# =============================================================================
# AKS (Azure Kubernetes Service) Configuration
# =============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.34.1"

  validation {
    condition     = can(regex("^1\\.(30|31|32|33|34)(\\.\\d+)?$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.30, 1.31, 1.32, 1.33, or 1.34.x"
  }
}

# System Node Pool (B2s - minimum for Azure, hosts system + application workloads)
variable "aks_system_node_count" {
  description = "Number of nodes in the AKS system node pool"
  type        = number
  default     = 1

  validation {
    condition     = var.aks_system_node_count >= 1 && var.aks_system_node_count <= 10
    error_message = "AKS system node count must be between 1 and 10"
  }
}

variable "aks_system_node_vm_size" {
  description = "VM size for AKS system node pool (B2ms = 2 vCPU, 8 GB RAM, 1250 Mbps network - upgraded from B2s for better performance)"
  type        = string
  default     = "Standard_B2ms"
}

variable "aks_enable_auto_scaling" {
  description = "Enable auto-scaling for AKS system node pool (scales nodes based on workload demand for cost optimization)"
  type        = bool
  default     = true
}

variable "aks_system_node_min_count" {
  description = "Minimum number of nodes when auto-scaling is enabled (3 recommended for HA with B2ms)"
  type        = number
  default     = 3

  validation {
    condition     = var.aks_system_node_min_count >= 1 && var.aks_system_node_min_count <= 10
    error_message = "AKS minimum node count must be between 1 and 10"
  }
}

variable "aks_system_node_max_count" {
  description = "Maximum number of nodes when auto-scaling is enabled (scales up during high load)"
  type        = number
  default     = 5

  validation {
    condition     = var.aks_system_node_max_count >= 1 && var.aks_system_node_max_count <= 100
    error_message = "AKS maximum node count must be between 1 and 100"
  }
}

variable "aks_admin_group_object_ids" {
  description = "List of Azure AD group object IDs that will have admin access to the AKS cluster"
  type        = list(string)
  default     = []
}

# =============================================================================
# Log Analytics Controls
# =============================================================================
variable "log_analytics_sku" {
  description = "SKU for Log Analytics (only PerGB2018 supported; Standard/Premium deprecated by Azure)"
  type        = string
  default     = "PerGB2018"

  validation {
    condition     = var.log_analytics_sku == "PerGB2018"
    error_message = "Only PerGB2018 is supported. Standard and Premium are deprecated by Azure."
  }
}

variable "log_analytics_retention_in_days" {
  description = "Log retention in days (30-730, minimum enforced by Azure)"
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_in_days >= 30 && var.log_analytics_retention_in_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily ingestion quota in GB (0 = unlimited, min 0.023 GB = ~24 MB/day if set)"
  type        = number
  default     = 0

  validation {
    condition     = var.log_analytics_daily_quota_gb == 0 || var.log_analytics_daily_quota_gb >= 0.023
    error_message = "Daily quota must be 0 (unlimited) or >= 0.023 GB."
  }
}

# =============================================================================
# Application Insights (APM) Configuration
# =============================================================================

variable "app_insights_sampling_percentage" {
  description = "Percentage of telemetry to collect (0-100). 100 = no sampling. Lower values reduce costs but may miss data."
  type        = number
  default     = 100

  validation {
    condition     = var.app_insights_sampling_percentage >= 0 && var.app_insights_sampling_percentage <= 100
    error_message = "Sampling percentage must be between 0 and 100."
  }
}

variable "app_insights_daily_cap_gb" {
  description = "Daily data cap in GB (0 = no cap). Recommended: 1-5 GB for dev, 10+ for production."
  type        = number
  default     = 0

  validation {
    condition     = var.app_insights_daily_cap_gb >= 0
    error_message = "Daily cap must be 0 (no cap) or a positive number."
  }
}


# =============================================================================
# ArgoCD Configuration
# =============================================================================
# REMOVED: ArgoCD is now installed manually via install-argocd-aks.ps1 script.
# This variable is no longer used by Terraform.
# =============================================================================
# variable "argocd_admin_password" {
#   description = "ArgoCD admin password (minimum 8 characters)"
#   type        = string
#   sensitive   = true
#   default     = "ChangeMe123!"
#
#   validation {
#     condition     = length(var.argocd_admin_password) >= 8
#     error_message = "ArgoCD admin password must be at least 8 characters long"
#   }
# }

# =============================================================================
# ELASTICSEARCH Variables
# =============================================================================
variable "elasticsearch_game_endpoint" {
  type        = string
  description = "Elasticsearch endpoint URL"
}

variable "elasticsearch_game_apikey" {
  type        = string
  description = "Elasticsearch API key"
  sensitive   = true
}

variable "elasticsearch_game_projectid" {
  type        = string
  description = "Elasticsearch project ID"
}

variable "elasticsearch_game_indexprefix" {
  type        = string
  description = "Elasticsearch index name prefix"
}

# =============================================================================
# GRAFANA Variables
# =============================================================================
variable "grafana_logs_api_token" {
  description = "Grafana logs API token"
  type        = string
  sensitive   = true
}

variable "grafana_otel_prometheus_api_token" {
  description = "Grafana OpenTelemetry Prometheus API token"
  type        = string
  sensitive   = true
}

variable "grafana_otel_games_resource_attributes" {
  description = "Grafana OpenTelemetry games resource attributes"
  type        = string
}

variable "grafana_otel_users_resource_attributes" {
  description = "Grafana OpenTelemetry users resource attributes"
  type        = string
}

variable "grafana_otel_payments_resource_attributes" {
  description = "Grafana OpenTelemetry payments resource attributes"
  type        = string
}

variable "grafana_otel_exporter_endpoint" {
  description = "Grafana OpenTelemetry exporter endpoint"
  type        = string
}

variable "grafana_otel_exporter_protocol" {
  description = "Grafana OpenTelemetry exporter protocol"
  type        = string
}

variable "grafana_otel_auth_header" {
  description = "Grafana OpenTelemetry auth header"
  type        = string
  sensitive   = true
}

# =============================================================================
# SENDGRID Variables
# =============================================================================
variable "sendgrid_api_key" {
  description = "SendGrid API key for email functionality"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^SG\\.[A-Za-z0-9_-]{22}\\.[A-Za-z0-9_-]{43}$", var.sendgrid_api_key))
    error_message = "SendGrid API key must be a valid format starting with 'SG.' followed by 22 characters, a dot, and 43 characters."
  }
}

variable "sendgrid_email_new_user_tid" {
  description = "SendGrid template ID for new user welcome email"
  type        = string
}

variable "sendgrid_email_purchase_tid" {
  description = "SendGrid template ID for purchase confirmation email"
  type        = string
}

# =============================================================================
# Grafana Cloud Configuration
# =============================================================================
# These variables are used to configure the Grafana Agent to send metrics
# from the AKS cluster to Grafana Cloud.
# 
# To get these values:
# 1. Go to https://grafana.com and login to your Grafana Cloud account
# 2. Navigate to Connections → Add new connection → Prometheus
# 3. Copy the Remote Write Endpoint URL, Username, and generate an API Key
# 
# Add these as sensitive variables in Terraform Cloud workspace.

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write URL (e.g., https://prometheus-prod-01-eu-west-0.grafana.net)"
  type        = string
  default     = ""
}

variable "grafana_cloud_prometheus_username" {
  description = "Grafana Cloud Prometheus username (Instance ID, e.g., 123456)"
  type        = string
  default     = ""
}

variable "grafana_cloud_prometheus_api_key" {
  description = "Grafana Cloud Prometheus API key (starts with glc_)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_cloud_loki_url" {
  description = "Grafana Cloud Loki URL for logs (optional, e.g., https://logs-prod-eu-west-0.grafana.net)"
  type        = string
  default     = ""
}

variable "grafana_cloud_loki_username" {
  description = "Grafana Cloud Loki username (optional, usually same as Prometheus username)"
  type        = string
  default     = ""
}

variable "grafana_cloud_loki_api_key" {
  description = "Grafana Cloud Loki API key (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_grafana_agent" {
  description = "Enable Grafana Agent for monitoring (requires Grafana Cloud credentials)"
  type        = bool
  default     = false
}

