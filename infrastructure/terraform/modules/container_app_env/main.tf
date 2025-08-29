// -----------------------------------------------------------------------------
// Container App Environment Module
// Deploys a Container App Environment with integration to Log Analytics
// -----------------------------------------------------------------------------

resource "azurerm_container_app_environment" "container_app_env" {
  name                       = "${var.name_prefix}-env"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id

  tags = var.tags
}
