# =============================================================================
# Azure Virtual Network for AKS
# =============================================================================

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet"
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Create Subnet for AKS nodes
resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.name_prefix}-aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.aks_subnet_address_prefixes

  # Required for Azure CNI
  service_endpoints = var.service_endpoints
}
