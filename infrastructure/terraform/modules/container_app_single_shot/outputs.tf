output "container_app_id" {
  description = "Container App resource ID"
  value       = azurerm_container_app.main.id
}

output "container_app_name" {
  description = "Container App name"
  value       = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  description = "Latest revision FQDN (ingress endpoint)"
  value       = azurerm_container_app.main.latest_revision_fqdn
}

output "system_assigned_identity_principal_id" {
  description = "System Assigned Managed Identity principalId"
  value       = azurerm_container_app.main.identity[0].principal_id
}

output "system_assigned_identity_tenant_id" {
  description = "Tenant ID for the System Assigned Managed Identity"
  value       = azurerm_container_app.main.identity[0].tenant_id
}

output "role_assignment_key_vault_secrets_user_id" {
  description = "Key Vault Secrets User role assignment ID"
  value       = local.enable_key_vault ? azurerm_role_assignment.kv_secrets_user[0].id : null
}

output "role_assignment_acr_pull_id" {
  description = "ACR Pull role assignment ID"
  value       = local.enable_acr_pull ? azurerm_role_assignment.acr_pull[0].id : null
}

output "container_image_deployed" {
  value       = var.container_image_acr
  description = "Final container image used in the deployment"
}
