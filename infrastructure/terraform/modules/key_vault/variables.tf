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