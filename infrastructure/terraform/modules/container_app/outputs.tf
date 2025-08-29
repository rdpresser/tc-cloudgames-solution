# ===================================================================================================
# Container App Module Outputs
# ===================================================================================================

output "container_app_id" {
  description = "The ID of the Container App"
  value       = azurerm_container_app.main.id
}

output "container_app_name" {
  description = "The name of the Container App"
  value       = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  description = "The FQDN of the Container App"
  value       = azurerm_container_app.main.latest_revision_fqdn
}

output "container_app_url" {
  description = "The URL of the Container App"
  value       = "https://${azurerm_container_app.main.latest_revision_fqdn}"
}

output "system_assigned_identity_principal_id" {
  description = "The Principal ID of the System Assigned Managed Identity"
  value       = data.azurerm_container_app.identity.identity[0].principal_id
}

output "system_assigned_identity_tenant_id" {
  description = "The Tenant ID of the System Assigned Managed Identity"
  value       = data.azurerm_container_app.identity.identity[0].tenant_id
}
