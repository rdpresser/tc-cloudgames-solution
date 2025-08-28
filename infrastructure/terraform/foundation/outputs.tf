# =============================================================================
# Outputs: Resource Group (Foundation)
# =============================================================================

# Resource Group name created in foundation
output "foundation_rg_name" {
  description = "The name of the Resource Group created in foundation"
  value       = module.resource_group.name
}

# Resource Group ID created in foundation
output "foundation_rg_id" {
  description = "The ID of the Resource Group created in foundation"
  value       = module.resource_group.id
}

# =============================================================================
# Outputs: PostgreSQL Flexible Server (via module)
# =============================================================================

# PostgreSQL server name
output "postgres_server_name" {
  description = "The name of the PostgreSQL server"
  value       = module.postgres.postgres_server_name
}

# Fully Qualified Domain Name (FQDN) of the PostgreSQL server
output "postgres_server_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server"
  value       = module.postgres.postgres_server_fqdn
}

# Resource ID of the PostgreSQL server
output "postgres_server_id" {
  description = "The ID of the PostgreSQL server"
  value       = module.postgres.postgres_server_id
}

# PostgreSQL server version
output "postgres_server_version" {
  description = "The version of the PostgreSQL server"
  value       = module.postgres.postgres_server_version
}

# PostgreSQL databases created on the server
output "postgres_databases" {
  description = "Map of PostgreSQL databases created on the server"
  value       = module.postgres.postgres_databases
}

# Default PostgreSQL port
output "postgres_port" {
  description = "The port of the PostgreSQL server"
  value       = module.postgres.postgres_port
}

# =============================================================================
# Outputs: Azure Container Registry (Foundation)
# =============================================================================

# ACR name
output "foundation_acr_name" {
  description = "The name of the Azure Container Registry created in foundation"
  value       = module.acr.acr_name
}

# ACR login server URL (used by container apps)
output "foundation_acr_login_server" {
  description = "The login server URL of the Azure Container Registry created in foundation"
  value       = module.acr.acr_login_server
}

# ACR Resource ID
output "foundation_acr_id" {
  description = "The resource ID of the Azure Container Registry created in foundation"
  value       = module.acr.acr_id
}

# ACR SKU
output "foundation_acr_sku" {
  description = "The SKU of the Azure Container Registry created in foundation"
  value       = module.acr.acr_sku
}

# ACR admin user enabled
output "foundation_acr_admin_enabled" {
  description = "Whether the admin user is enabled for the Azure Container Registry created in foundation"
  value       = module.acr.acr_admin_enabled
}
