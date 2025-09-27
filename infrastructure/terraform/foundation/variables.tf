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
# Elasticsearch Configuration Variables
# =============================================================================

variable "elasticsearch_cpu" {
  description = "CPU cores for Elasticsearch container"
  type        = number
  default     = 2

  validation {
    condition     = var.elasticsearch_cpu >= 1 && var.elasticsearch_cpu <= 4
    error_message = "Elasticsearch CPU must be between 1 and 4 cores."
  }
}

variable "elasticsearch_memory" {
  description = "Memory in GB for Elasticsearch container"
  type        = number
  default     = 4

  validation {
    condition     = var.elasticsearch_memory >= 2 && var.elasticsearch_memory <= 8
    error_message = "Elasticsearch memory must be between 2 and 8 GB."
  }
}

variable "elasticsearch_java_heap_size" {
  description = "Java heap size for Elasticsearch (e.g., '2g', '4g')"
  type        = string
  default     = "2g"

  validation {
    condition     = can(regex("^[0-9]+[gG]$", var.elasticsearch_java_heap_size))
    error_message = "Elasticsearch Java heap size must be in format like '2g' or '4g'."
  }
}

# =============================================================================
# Kibana Configuration Variables
# =============================================================================

variable "enable_kibana" {
  description = "Enable Kibana container"
  type        = bool
  default     = false
}

variable "kibana_cpu" {
  description = "CPU cores for Kibana container"
  type        = number
  default     = 1

  validation {
    condition     = var.kibana_cpu >= 1 && var.kibana_cpu <= 2
    error_message = "Kibana CPU must be between 1 and 2 cores."
  }
}

variable "kibana_memory" {
  description = "Memory in GB for Kibana container"
  type        = number
  default     = 2

  validation {
    condition     = var.kibana_memory >= 1 && var.kibana_memory <= 4
    error_message = "Kibana memory must be between 1 and 4 GB."
  }
}

# =============================================================================
# Storage Configuration Variables
# =============================================================================

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be LRS, GRS, RAGRS, or ZRS."
  }
}

variable "storage_quota_gb" {
  description = "Storage quota in GB for Elasticsearch data"
  type        = number
  default     = 100

  validation {
    condition     = var.storage_quota_gb >= 10 && var.storage_quota_gb <= 1024
    error_message = "Storage quota must be between 10 and 1024 GB."
  }
}

# =============================================================================
# Monitoring Configuration Variables
# =============================================================================

variable "enable_monitoring" {
  description = "Enable Application Insights and Log Analytics monitoring"
  type        = bool
  default     = true
}

# =============================================================================
# Network Configuration Variables
# =============================================================================

variable "allowed_source_ips" {
  description = "List of IP addresses allowed to access Elasticsearch"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_private_access" {
  description = "Enable private access only (disable public IP)"
  type        = bool
  default     = false
}