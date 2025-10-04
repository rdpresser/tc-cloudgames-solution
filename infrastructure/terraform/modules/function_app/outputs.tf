# =============================================================================
# Azure Function App Module Outputs
# =============================================================================

output "function_app_id" {
  description = "ID of the Function App"
  value       = azurerm_linux_function_app.main.id
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_identity" {
  description = "Identity of the Function App"
  value       = azurerm_linux_function_app.main.identity
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.function_storage.name
}

output "storage_account_connection_string" {
  description = "Connection string of the storage account"
  value       = azurerm_storage_account.function_storage.primary_connection_string
  sensitive   = true
}

output "application_insights_id" {
  description = "ID of the Application Insights"
  value       = azurerm_application_insights.function_insights.id
}

output "application_insights_connection_string" {
  description = "Connection string of Application Insights"
  value       = azurerm_application_insights.function_insights.connection_string
  sensitive   = true
}
