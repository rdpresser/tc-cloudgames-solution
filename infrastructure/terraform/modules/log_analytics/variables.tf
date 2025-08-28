// -----------------------------------------------------------------------------
// Log Analytics module variables
// Provides default values for common Log Analytics Workspace configuration
// -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Name prefix for Log Analytics Workspace"
  type        = string
}

variable "location" {
  description = "Azure region where the Log Analytics Workspace will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where Log Analytics Workspace will be deployed"
  type        = string
}

variable "sku" {
  description = "SKU for the Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Retention period in days for Log Analytics Workspace"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
