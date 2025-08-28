# =============================================================================
# Outputs: Resource Group
# =============================================================================

# Resource Group name
output "foundation_rg_name" {
  description = "The name of the Resource Group created in foundation"
  value       = module.resource_group.name
}

# Resource Group ID
output "foundation_rg_id" {
  description = "The ID of the Resource Group created in foundation"
  value       = module.resource_group.id
}

# =============================================================================
# Outputs: PostgreSQL Flexible Server
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
