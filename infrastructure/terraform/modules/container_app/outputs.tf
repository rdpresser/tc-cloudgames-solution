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
  value       = azurerm_container_app.main.identity[0].principal_id
}

output "system_assigned_identity_tenant_id" {
  description = "The Tenant ID of the System Assigned Managed Identity"
  value       = azurerm_container_app.main.identity[0].tenant_id
}

# =============================================================================
# Role Assignment Outputs
# =============================================================================

output "role_assignment_key_vault_secrets_user_id" {
  description = "ID of the Key Vault Secrets User role assignment"
  value       = azurerm_role_assignment.key_vault_secrets_user.id
}

output "role_assignment_acr_pull_id" {
  description = "ID of the ACR Pull role assignment"
  value       = azurerm_role_assignment.acr_pull.id
}
