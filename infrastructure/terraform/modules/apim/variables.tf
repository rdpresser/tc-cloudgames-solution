variable "name_prefix" {
  description = "Name prefix for APIM"
  type        = string
}

variable "location" {
  description = "Azure region where APIM will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where APIM will be deployed"
  type        = string
}

variable "publisher_name" {
  description = "Publisher name for APIM"
  type        = string
  default     = "CloudGames Team"
}

variable "publisher_email" {
  description = "Publisher email for APIM"
  type        = string
  default     = "admin@cloudgames.com"
}

variable "sku_name" {
  description = "SKU for APIM (Consumption_0, Developer_1, Basic_1, Standard_1, Premium_1)"
  type        = string
  default     = "Consumption_0"
}

variable "backend_url" {
  description = "Backend URL for AKS Ingress (e.g., http://20.161.217.114). Set to null to skip API/backend configuration."
  type        = string
  default     = null
}

variable "require_subscription" {
  description = "Require subscription key for API access"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
