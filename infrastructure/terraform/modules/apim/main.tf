resource "azurerm_api_management" "this" {
    name                = "${var.name_prefix}-apim"
    location            = var.location
    resource_group_name = var.resource_group_name

    publisher_name  = "tccloudgames-llc"
    publisher_email = "tccloudgames@tccloudgames.com"

    sku_name = "Consumption_0"
    tags = var.tags
}

