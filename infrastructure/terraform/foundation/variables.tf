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
  default     = "brazilsouth"

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
