# =============================================================================
# App Service Plan Module Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "service_name" {
  description = "Name of the service (used in resource naming)"
  type        = string
  default     = "asp"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the App Service Plan"
  type        = string
  default     = "Y1"  # Consumption plan for serverless functions
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
