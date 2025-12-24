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
  description = "SKU for the Log Analytics Workspace (PerGB2018 is the only viable option; Standard/Premium deprecated)"
  type        = string
  default     = "PerGB2018"
  
  validation {
    condition     = var.sku == "PerGB2018"
    error_message = "Only PerGB2018 is supported for new workspaces. Standard and Premium are deprecated by Azure."
  }
}

variable "retention_in_days" {
  description = "Retention period in days for Log Analytics Workspace (30-730 days; minimum 30)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (0 or null = unlimited, minimum 0.023 GB if set)"
  type        = number
  default     = 0
  
  validation {
    condition     = var.daily_quota_gb == 0 || var.daily_quota_gb >= 0.023
    error_message = "Daily quota must be 0 (unlimited) or >= 0.023 GB (Azure minimum)."
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
