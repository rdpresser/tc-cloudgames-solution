output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.key_vault.name
}

output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.key_vault.id
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.key_vault.vault_uri
}

output "key_vault_tenant_id" {
  description = "The Tenant ID used by the Key Vault"
  value       = azurerm_key_vault.key_vault.tenant_id
}

output "key_vault_sku" {
  description = "The SKU of the Key Vault"
  value       = azurerm_key_vault.key_vault.sku_name
}