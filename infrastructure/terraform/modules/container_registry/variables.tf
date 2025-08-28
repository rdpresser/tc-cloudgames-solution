# Prefix for ACR resource names (includes random suffix if needed)
variable "name_prefix" {
  type        = string
  description = "Prefix for ACR resource names (can include random suffix)"
}

# Azure region where the ACR will be deployed
variable "location" {
  type        = string
  description = "Azure region where the ACR will be deployed"
}

# Resource Group name where the ACR will be created
variable "resource_group_name" {
  type        = string
  description = "The Resource Group name where ACR resources will be created"
}

# SKU for ACR (Standard, Premium, etc.)
variable "sku" {
  type        = string
  description = "SKU for the Azure Container Registry"
  default     = "Standard"
}

# Enable admin user for ACR
variable "admin_enabled" {
  type        = bool
  description = "Enable the admin user for ACR"
  default     = true
}

# Common tags to apply to all ACR resources
variable "tags" {
  type        = map(string)
  description = "Common tags applied to ACR resources"
  default     = {
    Environment = "dev"
    Project     = "TC Cloud Games"
    ManagedBy   = "Terraform"
  }
}
