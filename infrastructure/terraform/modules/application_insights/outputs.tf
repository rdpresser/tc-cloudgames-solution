// -----------------------------------------------------------------------------
// Application Insights Module - Outputs
// -----------------------------------------------------------------------------

output "id" {
  description = "Resource ID of the Application Insights instance"
  value       = azurerm_application_insights.main.id
}

output "name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.main.name
}

output "instrumentation_key" {
  description = "Instrumentation Key for Application Insights (legacy, use connection_string instead)"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "connection_string" {
  description = "Connection String for Application Insights (recommended for Azure.Monitor.OpenTelemetry.AspNetCore)"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "app_id" {
  description = "Application ID of the Application Insights instance"
  value       = azurerm_application_insights.main.app_id
}
