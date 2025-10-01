# =============================================================================
# Environment and Project Configuration
# =============================================================================

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
# API Management Configuration
# =============================================================================

variable "apim_sku_name" {
  description = "SKU name for API Management"
  type        = string
  default     = "Developer_1"

  validation {
    condition = contains([
      "Developer_1", "Developer_2", "Developer_3", "Developer_4", "Developer_5",
      "Standard_1", "Standard_2", "Standard_4", "Standard_8", "Standard_10",
      "Premium_1", "Premium_2", "Premium_4", "Premium_8", "Premium_10"
    ], var.apim_sku_name)
    error_message = "The apim_sku_name must be a valid Azure API Management SKU."
  }
}

variable "publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "tc-cloud-games"
}

variable "publisher_email" {
  description = "Publisher email for API Management"
  type        = string
  default     = "tc-cloud-games@email.com"
}

# =============================================================================
# Foundation Dependencies
# =============================================================================

variable "foundation_resource_group_name" {
  description = "Name of the resource group from foundation"
  type        = string
}

variable "foundation_resource_group_location" {
  description = "Location of the resource group from foundation"
  type        = string
}

# =============================================================================
# OpenAPI Files Validation
# =============================================================================

variable "validate_openapi_files" {
  description = "Enable validation of OpenAPI files existence"
  type        = bool
  default     = true
}
