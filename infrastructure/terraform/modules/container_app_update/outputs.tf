output "container_app_id" {
  description = "ID of the updated Container App"
  value       = azurerm_container_app.updated.id
}

output "container_app_fqdn" {
  description = "FQDN of the updated Container App"
  value       = azurerm_container_app.updated.ingress[0].fqdn
}

output "container_app_name" {
  description = "Name of the updated Container App"
  value       = azurerm_container_app.updated.name
}

output "system_assigned_identity_principal_id" {
  description = "Principal ID of the system assigned identity"
  value       = azurerm_container_app.updated.identity[0].principal_id
}
