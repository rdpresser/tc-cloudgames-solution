// -----------------------------------------------------------------------------
// Redis module variables
// Provides default values for common Redis configuration
// -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Name prefix for Redis Cache"
  type        = string
}

variable "location" {
  description = "Azure region where Redis Cache will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where Redis Cache will be deployed"
  type        = string
}

variable "sku_name" {
  description = "Redis SKU name (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"
}

variable "sku_family" {
  description = "Redis SKU family (C = Basic/Standard, P = Premium)"
  type        = string
  default     = "C"
}

variable "sku_capacity" {
  description = "Redis instance size (0-6 depending on SKU)"
  type        = number
  default     = 0
}

variable "enable_non_ssl_port" {
  description = "Enable the non-SSL port (default: false)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
