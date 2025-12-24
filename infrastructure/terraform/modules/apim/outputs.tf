# =============================================================================
# Azure API Management Outputs
# =============================================================================

# The name of the API Management service
output "apim_name" {
  value       = azurerm_api_management.this.name
  description = "The name of the Azure API Management service"
}

# The ID of the API Management service
output "apim_id" {
  value       = azurerm_api_management.this.id
  description = "The resource ID of the Azure API Management service"
}

# The resource group name
output "resource_group_name" {
  value       = azurerm_api_management.this.resource_group_name
  description = "The resource group name of the Azure API Management service"
}

# The location of the API Management service
output "apim_location" {
  value       = azurerm_api_management.this.location
  description = "The location of the Azure API Management service"
}

# The gateway URL of the API Management service
output "apim_gateway_url" {
  value       = azurerm_api_management.this.gateway_url
  description = "The gateway URL of the Azure API Management service"
}

# The management API URL of the API Management service
output "apim_management_api_url" {
  value       = azurerm_api_management.this.management_api_url
  description = "The management API URL of the Azure API Management service"
}

# The portal URL of the API Management service
output "apim_portal_url" {
  value       = azurerm_api_management.this.portal_url
  description = "The portal URL of the Azure API Management service"
}

# For backward compatibility (kept for module usage in main.tf)
output "name" {
  value = azurerm_api_management.this.name
}
# CloudGames API Paths
output "games_api_url" {
  description = "Full URL for Games API"
  value       = var.backend_url != null ? "${azurerm_api_management.this.gateway_url}/games" : null
}

output "user_api_url" {
  description = "Full URL for User API"
  value       = var.backend_url != null ? "${azurerm_api_management.this.gateway_url}/user" : null
}

output "payments_api_url" {
  description = "Full URL for Payments API"
  value       = var.backend_url != null ? "${azurerm_api_management.this.gateway_url}/payments" : null
}
