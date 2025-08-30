variable "name_prefix" {
  description = "Name prefix for Key Vault (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Azure region where the Key Vault will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where the Key Vault will be deployed"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "sku_name" {
  description = "The SKU name of the Key Vault"
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "The number of days that items should be retained for once soft-deleted"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Is Purge Protection enabled for this Key Vault"
  type        = bool
  default     = false
}

variable "tenant_id" {
  description = "The Tenant ID used by the Key Vault"
  type        = string
}

# =============================================================================
# Infrastructure Secrets Variables
# =============================================================================

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
}

variable "acr_login_server" {
  description = "Azure Container Registry login server"
  type        = string
}

variable "acr_admin_username" {
  description = "Azure Container Registry admin username"
  type        = string
}

variable "acr_admin_password" {
  description = "Azure Container Registry admin password"
  type        = string
  sensitive   = true
}

variable "postgres_fqdn" {
  description = "PostgreSQL server FQDN"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL server port"
  type        = string
}

variable "postgres_users_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "tc-cloudgames-users-db"
}

variable "postgres_games_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "tc-cloudgames-games-db"
}

variable "postgres_payments_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "tc-cloudgames-payments-db"
}

variable "postgres_admin_login" {
  description = "PostgreSQL admin login"
  type        = string
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "redis_hostname" {
  description = "Redis cache hostname"
  type        = string
}

variable "redis_ssl_port" {
  description = "Redis cache SSL port"
  type        = string
}

variable "redis_primary_access_key" {
  description = "Redis cache primary access key"
  type        = string
  sensitive   = true
}

variable "servicebus_namespace" {
  description = "Service Bus namespace name"
  type        = string
}