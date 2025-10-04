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

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string

  validation {
    condition = can(regex("^[a-f0-9-]{36}$", var.tenant_id))
    error_message = "Tenant ID must be a valid GUID format."
  }
}

variable "service_bus_connection_string" {
  description = "Service Bus connection string"
  type        = string
  default     = null

  validation {
    condition = var.service_bus_connection_string == null || can(regex("^Endpoint=sb://[^;]+;SharedAccessKeyName=[^;]+;SharedAccessKey=[^;]+$", var.service_bus_connection_string))
    error_message = "Service Bus connection string must be a valid Azure Service Bus connection string format."
  }
}

variable "sendgrid_api_key" {
  description = "SendGrid API key"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = var.sendgrid_api_key == null || can(regex("^SG\\.[A-Za-z0-9_-]{22}\\.[A-Za-z0-9_-]{43}$", var.sendgrid_api_key))
    error_message = "SendGrid API key must be a valid format starting with 'SG.' followed by 22 characters, a dot, and 43 characters."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
