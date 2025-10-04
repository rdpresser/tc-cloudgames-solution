# =============================================================================
# App Service Plan Module
# =============================================================================
# This module creates an App Service Plan for Azure Functions
# =============================================================================

locals {
  clean_prefix      = replace(replace(var.name_prefix, "--", "-"), "--", "-")
  clean_service     = replace(replace(var.service_name, "--", "-"), "--", "-")
  proposed_name     = "${local.clean_prefix}-${local.clean_service}"
  appserviceplan_name = length(local.proposed_name) > 60 ? substr(local.proposed_name, 0, 60) : local.proposed_name
}

# =============================================================================
# App Service Plan
# =============================================================================
resource "azurerm_service_plan" "main" {
  name                = local.appserviceplan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.sku_name

  tags = var.tags
}
