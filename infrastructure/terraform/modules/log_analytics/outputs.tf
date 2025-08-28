// -----------------------------------------------------------------------------
// Log Analytics module outputs
// -----------------------------------------------------------------------------

output "log_analytics_name" {
  description = "The name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.logs.name
}

output "log_analytics_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.logs.id
}

output "log_analytics_location" {
  description = "The location of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.logs.location
}

output "log_analytics_sku" {
  description = "The SKU of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.logs.sku
}

output "log_analytics_retention_days" {
  description = "The retention period in days for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.logs.retention_in_days
}
