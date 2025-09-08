# =============================================================================
# Key Vault Outputs
# =============================================================================

# The Resource ID of the Key Vault
output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.key_vault.id
}

# The URI of the Key Vault (normalized without trailing slash)
output "key_vault_uri" {
  description = "The URI of the Key Vault (normalized without trailing slash)"
  value       = trimsuffix(azurerm_key_vault.key_vault.vault_uri, "/")
}

# The name of the Key Vault
output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.key_vault.name
}

# Secrets for Container Apps reference
output "secrets" {
  description = "Key Vault secrets for Container Apps binding"
  value = {
    acr_name                           = azurerm_key_vault_secret.acr_name.id
    acr_login_server                   = azurerm_key_vault_secret.acr_login_server.id
    db_host                            = azurerm_key_vault_secret.db_host.id
    db_port                            = azurerm_key_vault_secret.db_port.id
    db_name_users                      = azurerm_key_vault_secret.db_name_users.id
    db_name_games                      = azurerm_key_vault_secret.db_name_games.id
    db_name_payments                   = azurerm_key_vault_secret.db_name_payments.id
    db_name_maintenance                = azurerm_key_vault_secret.db_name_maintenance.id
    db_admin_login                     = azurerm_key_vault_secret.db_admin_login.id
    db_password                        = azurerm_key_vault_secret.db_password.id
    cache_host                         = azurerm_key_vault_secret.cache_host.id
    cache_port                         = azurerm_key_vault_secret.cache_port.id
    cache_password                     = azurerm_key_vault_secret.cache_password.id
    cache_secure                       = azurerm_key_vault_secret.cache_secure.id
    servicebus_namespace               = azurerm_key_vault_secret.servicebus_namespace.id
    servicebus_connection_string       = azurerm_key_vault_secret.servicebus_connection_string.id
    servicebus_auto_provision          = azurerm_key_vault_secret.servicebus_auto_provision.id
    servicebus_max_delivery_count      = azurerm_key_vault_secret.servicebus_max_delivery_count.id
    servicebus_enable_dead_lettering   = azurerm_key_vault_secret.servicebus_enable_dead_lettering.id
    servicebus_auto_purge_on_startup   = azurerm_key_vault_secret.servicebus_auto_purge_on_startup.id
    servicebus_use_control_queues      = azurerm_key_vault_secret.servicebus_use_control_queues.id
  }
}
