resource "azurerm_api_management_api" "this" {
  name                = var.name_prefix
  resource_group_name = var.resource_group_name
  api_management_name = var.api_management_name

  revision     = "1"
  display_name = var.display_name
  path         = var.path
  protocols    = ["https"]

  import {
    content_format = "openapi-link"
    content_value  = var.swagger_url
  }
}

# Política geral da API (opcional)
resource "azurerm_api_management_api_policy" "this" {
  count = var.api_policy != null ? 1 : 0

  api_name            = azurerm_api_management_api.this.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  xml_content         = var.api_policy
}

# Policies de operações específicas (opcional)
resource "azurerm_api_management_api_operation_policy" "this" {
  for_each = var.operation_policies

  api_name            = azurerm_api_management_api.this.name
  operation_id        = each.key
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  xml_content         = each.value
}
