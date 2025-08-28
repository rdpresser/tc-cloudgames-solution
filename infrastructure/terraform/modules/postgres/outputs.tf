# =============================================================================
# PostgreSQL Outputs
# =============================================================================

# PostgreSQL server name
output "postgres_server_name" {
  description = "The name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres_server.name
}

# Fully Qualified Domain Name (FQDN) of the PostgreSQL server
output "postgres_server_fqdn" {
  description = "The fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres_server.fqdn
}

# Resource ID of the PostgreSQL server
output "postgres_server_id" {
  description = "The ID of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres_server.id
}

# PostgreSQL server version
output "postgres_server_version" {
  description = "The version of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgres_server.version
}

# Map of PostgreSQL database names created on the server
output "postgres_databases" {
  description = "A map of PostgreSQL databases created on the server"
  value       = { for db in azurerm_postgresql_flexible_server_database.databases : db.name => db.name }
}

# Default PostgreSQL port
output "postgres_port" {
  description = "The port of the PostgreSQL server"
  value       = 5432
}

# Example: server firewall rules output (optional)
output "postgres_firewall_rules" {
  description = "List of PostgreSQL server firewall rule names"
  value       = [
    azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services.name,
    azurerm_postgresql_flexible_server_firewall_rule.client_ip.name
  ]
}
