resource "azurerm_resource_group" "this" {
  name     = var.name_prefix
  location = var.location
  tags     = var.tags
}
