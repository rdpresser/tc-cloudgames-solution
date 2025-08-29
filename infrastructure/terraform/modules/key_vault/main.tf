# =============================================================================
# Key Vault
# =============================================================================

resource "azurerm_key_vault" "key_vault" {
  name                       = "${var.name_prefix}kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days

  # Enable RBAC for Container Apps Managed Identity integration
  enable_rbac_authorization = true
  purge_protection_enabled  = var.purge_protection_enabled

  # Allow Container Apps to access
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}
