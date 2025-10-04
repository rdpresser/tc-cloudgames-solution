# =============================================================================
# Azure Function App Module Outputs
# =============================================================================

# The ID of the Function App
output "function_app_id" {
  description = "The resource ID of the Azure Function App"
  value       = azurerm_linux_function_app.main.id
}

# The name of the Function App
output "function_app_name" {
  description = "The name of the Azure Function App"
  value       = azurerm_linux_function_app.main.name
}

# The default hostname of the Function App
output "function_app_default_hostname" {
  description = "The default hostname of the Azure Function App"
  value       = azurerm_linux_function_app.main.default_hostname
}

# The System Assigned Identity of the Function App
output "function_app_identity" {
  description = "The System Assigned Identity of the Azure Function App"
  value       = azurerm_linux_function_app.main.identity
}

# Principal ID of the System Assigned Identity
output "function_app_principal_id" {
  description = "The Principal ID of the Function App's System Assigned Identity"
  value       = azurerm_linux_function_app.main.identity[0].principal_id
}

# Storage Account details
output "storage_account_id" {
  description = "The resource ID of the storage account"
  value       = azurerm_storage_account.function_storage.id
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.function_storage.name
}

output "storage_account_connection_string" {
  description = "The connection string of the storage account"
  value       = azurerm_storage_account.function_storage.primary_connection_string
  sensitive   = true
}

# Application Insights details
output "application_insights_id" {
  description = "The resource ID of Application Insights"
  value       = azurerm_application_insights.function_insights.id
}

output "application_insights_instrumentation_key" {
  description = "The instrumentation key of Application Insights"
  value       = azurerm_application_insights.function_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "The connection string of Application Insights"
  value       = azurerm_application_insights.function_insights.connection_string
  sensitive   = true
}

# RBAC Role Assignment ID
output "role_assignment_kv_secrets_user_id" {
  description = "The ID of the Key Vault Secrets User role assignment"
  value       = var.key_vault_id != null ? azurerm_role_assignment.function_app_kv_secrets_user.id : null
}
