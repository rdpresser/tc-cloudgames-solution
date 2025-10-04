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

