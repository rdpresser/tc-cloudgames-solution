# =============================================================================
# Azure Function App Module Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "service_name" {
  description = "Name of the service (used in resource naming)"
  type        = string
  default     = "functions"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "app_service_plan_id" {
  description = "ID of the App Service Plan for the Function App"
  type        = string

  validation {
    condition = can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft.Web/serverfarms/[^/]+$", var.app_service_plan_id))
    error_message = "App Service Plan ID must be a valid Azure resource ID format."
  }
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  type        = string

  validation {
    condition = can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_id))
    error_message = "Log Analytics Workspace ID must be a valid Azure resource ID format."
  }
}

variable "key_vault_id" {
  description = "ID of the Key Vault for secrets"
  type        = string
  default     = null

  validation {
    condition = var.key_vault_id == null || can(regex("^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft.KeyVault/vaults/[^/]+$", var.key_vault_id))
    error_message = "Key Vault ID must be a valid Azure resource ID format."
  }
}

variable "key_vault_uri" {
  description = "URI of the Key Vault for secret references"
  type        = string
  default     = null

  validation {
    condition = var.key_vault_uri == null || can(regex("^https://[a-zA-Z0-9-]+\\.vault\\.azure\\.net/?$", var.key_vault_uri))
    error_message = "Key Vault URI must be a valid Azure Key Vault URI format."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
