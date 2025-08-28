// -----------------------------------------------------------------------------
// Container App Environment module outputs
// -----------------------------------------------------------------------------

output "container_app_environment_name" {
  description = "The name of the Container App Environment"
  value       = azurerm_container_app_environment.container_app_env.name
}

output "container_app_environment_id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.container_app_env.id
}

output "container_app_environment_location" {
  description = "The location of the Container App Environment"
  value       = azurerm_container_app_environment.container_app_env.location
}
