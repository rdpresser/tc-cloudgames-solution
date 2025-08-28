# Prefix for PostgreSQL resource names (includes random suffix if needed)
variable "name_prefix" {
  type        = string
  description = "Prefix for PostgreSQL resource names (can include random suffix)"
}

# Azure region where the PostgreSQL server will be deployed
variable "location" {
  type        = string
  description = "Azure region where PostgreSQL server will be deployed"
}

# Resource Group name where the PostgreSQL server will be created
variable "resource_group_name" {
  type        = string
  description = "The Resource Group name where PostgreSQL resources will be created"
}

# PostgreSQL administrator username
variable "postgres_admin_login" {
  type        = string
  description = "PostgreSQL administrator username"
}

# PostgreSQL administrator password
variable "postgres_admin_password" {
  type        = string
  description = "PostgreSQL administrator password"
  sensitive   = true
}

# SKU for PostgreSQL server (use cheaper SKU for dev, change for prod)
variable "postgres_sku" {
  type        = string
  description = "SKU for PostgreSQL server"
  default     = "B_Standard_B1ms"
}

# PostgreSQL version
variable "postgres_version" {
  type        = string
  description = "PostgreSQL server version"
  default     = "16"
}

# Storage size in MB
variable "storage_mb" {
  type        = number
  description = "Storage size for PostgreSQL server in MB"
  default     = 32768
}

# List of databases to create on the PostgreSQL server
variable "databases" {
  type        = list(string)
  description = "List of PostgreSQL databases to create"
  default     = [
    "tc-cloudgames-users-db", 
    "tc-cloudgames-games-db", 
    "tc-cloudgames-payments-db"
  ]
}

# Common tags to apply to all PostgreSQL resources
variable "tags" {
  type        = map(string)
  description = "Common tags applied to PostgreSQL resources"
  default     = {
    Environment = "dev"
    Project     = "TC Cloud Games"
    ManagedBy   = "Terraform"
  }
}
