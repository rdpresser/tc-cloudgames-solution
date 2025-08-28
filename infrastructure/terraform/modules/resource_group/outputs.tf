# =============================================================================
# Resource Group Outputs
# =============================================================================

# Resource Group name
output "name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.this.name
}

# Resource Group ID
output "id" {
  description = "The ID of the Resource Group"
  value       = azurerm_resource_group.this.id
}

# Resource Group location
output "location" {
  description = "The location of the Resource Group"
  value       = azurerm_resource_group.this.location
}
