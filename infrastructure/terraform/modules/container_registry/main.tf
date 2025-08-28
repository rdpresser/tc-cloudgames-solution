# =============================================================================
# Azure Container Registry
# =============================================================================

# Create an Azure Container Registry
resource "azurerm_container_registry" "acr" {
  # Name of the ACR
  name = var.name_prefix

  # Resource Group where the ACR will be deployed
  resource_group_name = var.resource_group_name

  # Azure region where the ACR will be created
  location = var.location

  # SKU of the ACR (Standard, Premium, etc.)
  sku = var.sku

  # Enable the admin user for the ACR
  admin_enabled = var.admin_enabled

  # Apply common tags for organization and billing
  tags = var.tags
}
