# =============================================================================
# Azure Container Registry Outputs
# =============================================================================

# The name of the Container Registry
output "acr_name" {
  value       = azurerm_container_registry.acr.name
  description = "The name of the Azure Container Registry"
}

# The login server URL of the Container Registry (used by container apps)
output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The login server URL of the Azure Container Registry"
}

# The Resource ID of the Container Registry
output "acr_id" {
  value       = azurerm_container_registry.acr.id
  description = "The resource ID of the Azure Container Registry"
}

# The SKU of the Container Registry
output "acr_sku" {
  value       = azurerm_container_registry.acr.sku
  description = "The SKU of the Azure Container Registry"
}

# Indicates whether the admin user is enabled for the Container Registry
output "acr_admin_enabled" {
  value       = azurerm_container_registry.acr.admin_enabled
  description = "Whether the admin user is enabled for the Azure Container Registry"
}

# The admin password for the Azure Container Registry (sensitive)
output "acr_admin_password" {
  value       = azurerm_container_registry.acr.admin_password
  description = "The admin password for the Azure Container Registry"
  sensitive   = true
}

# The admin username for the Azure Container Registry
output "acr_admin_username" {
  value       = azurerm_container_registry.acr.admin_username
  description = "The admin username for the Azure Container Registry"
}
