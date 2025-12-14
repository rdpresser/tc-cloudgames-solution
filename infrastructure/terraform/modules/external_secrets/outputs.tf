# =============================================================================
# External Secrets Operator Outputs
# =============================================================================

output "eso_identity_id" {
  description = "ID of the User Assigned Identity for ESO"
  value       = azurerm_user_assigned_identity.eso_identity.id
}

output "eso_identity_client_id" {
  description = "Client ID of the User Assigned Identity for ESO"
  value       = azurerm_user_assigned_identity.eso_identity.client_id
}

output "eso_identity_principal_id" {
  description = "Principal ID of the User Assigned Identity for ESO"
  value       = azurerm_user_assigned_identity.eso_identity.principal_id
}

output "eso_identity_name" {
  description = "Name of the User Assigned Identity for ESO"
  value       = azurerm_user_assigned_identity.eso_identity.name
}

output "eso_namespace" {
  description = "Kubernetes namespace where ESO is installed"
  value       = var.eso_namespace
}

output "eso_service_account_name" {
  description = "Name of the ServiceAccount for ESO"
  value       = var.eso_service_account_name
}

output "federated_credential_name" {
  description = "Name of the Federated Identity Credential"
  value       = azurerm_federated_identity_credential.eso_federated_credential.name
}
