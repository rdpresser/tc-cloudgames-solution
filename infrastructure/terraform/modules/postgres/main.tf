# =============================================================================
# PostgreSQL Flexible Server
# =============================================================================
resource "azurerm_postgresql_flexible_server" "postgres_server" {
  # Server name with prefix and optional random suffix
  name                = "${var.name_prefix}-db"
  location            = var.location
  resource_group_name = var.resource_group_name
  zone                = "1"
  
  administrator_login    = var.postgres_admin_login
  administrator_password = var.postgres_admin_password

  sku_name   = var.postgres_sku
  version    = var.postgres_version
  storage_mb = var.storage_mb

  

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true

  tags = var.tags
}

# =============================================================================
# PostgreSQL Databases
# =============================================================================
resource "azurerm_postgresql_flexible_server_database" "databases" {
  for_each   = toset(var.databases)
  name       = each.value
  server_id  = azurerm_postgresql_flexible_server.postgres_server.id
  charset    = "UTF8"
  collation  = "pt_BR.utf8"
}

# =============================================================================
# Firewall rules
# =============================================================================
# Allow all Azure resources
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name        = "AllowAllAzureServices_2025-08-27"
  server_id   = azurerm_postgresql_flexible_server.postgres_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Example client IP rule (replace with your IP or variable)
resource "azurerm_postgresql_flexible_server_firewall_rule" "client_ip" {
  name        = "ClientIPAddress_2025-08-27"
  server_id   = azurerm_postgresql_flexible_server.postgres_server.id
  start_ip_address = "179.216.21.147"
  end_ip_address   = "179.216.21.147"
}
