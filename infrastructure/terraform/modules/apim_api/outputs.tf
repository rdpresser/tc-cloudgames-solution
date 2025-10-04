# =============================================================================
# API Management API Module Outputs
# =============================================================================

# The name of the API Management API
output "api_name" {
  description = "The name of the API Management API"
  value       = azurerm_api_management_api.this.name
}

# The ID of the API Management API
output "api_id" {
  description = "The resource ID of the API Management API"
  value       = azurerm_api_management_api.this.id
}

# The display name of the API Management API
output "api_display_name" {
  description = "The display name of the API Management API"
  value       = azurerm_api_management_api.this.display_name
}

# The path of the API Management API
output "api_path" {
  description = "The path of the API Management API"
  value       = azurerm_api_management_api.this.path
}

# The revision of the API Management API
output "api_revision" {
  description = "The revision of the API Management API"
  value       = azurerm_api_management_api.this.revision
}

# The operation policies configured for the API (temporarily empty)
output "operation_policies" {
  description = "Operation policies configured for the API (temporarily disabled)"
  value       = {}  # Empty since policies are disabled
}