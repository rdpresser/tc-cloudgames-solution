// -----------------------------------------------------------------------------
// Log Analytics Workspace Module
// Deploys a Log Analytics Workspace with configurable SKU and retention
// -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.name_prefix}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_in_days

  tags = var.tags
}
