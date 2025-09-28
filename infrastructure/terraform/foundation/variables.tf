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
