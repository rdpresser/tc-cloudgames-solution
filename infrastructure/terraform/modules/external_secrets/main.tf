# =============================================================================
# External Secrets Operator with Workload Identity
# =============================================================================
# This module:
# 1. Installs External Secrets Operator via Helm
# 2. Creates User Assigned Identity for ESO
# 3. Creates Federated Identity Credential for Workload Identity
# 4. Grants Key Vault Secrets User role to the UAI
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56" # Latest 4.x
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1" # Latest 3.x
    }
  }
}

# -----------------------------------------------------------------------------
# User Assigned Identity for External Secrets Operator
# -----------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "eso_identity" {
  name                = "${var.name_prefix}-eso-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Federated Identity Credential
# Links the Kubernetes ServiceAccount to the Azure User Assigned Identity
# -----------------------------------------------------------------------------
resource "azurerm_federated_identity_credential" "eso_federated_credential" {
  name                = "${var.name_prefix}-eso-federated-credential"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.eso_identity.id

  # The OIDC issuer URL from AKS
  issuer = var.aks_oidc_issuer_url

  # The Kubernetes ServiceAccount that will use this identity
  # Format: system:serviceaccount:<namespace>:<serviceaccount-name>
  subject = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"

  # The audience for the token
  audience = ["api://AzureADTokenExchange"]
}

# -----------------------------------------------------------------------------
# Key Vault Role Assignment - Key Vault Secrets User
# Allows the ESO identity to read secrets from Key Vault
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "eso_keyvault_secrets_user" {
  principal_id         = azurerm_user_assigned_identity.eso_identity.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = var.key_vault_id

  depends_on = [
    azurerm_user_assigned_identity.eso_identity
  ]
}

# -----------------------------------------------------------------------------
# Helm Values for External Secrets Operator
# -----------------------------------------------------------------------------
locals {
  eso_values = yamlencode({
    installCRDs = true
    
    serviceAccount = {
      create = true
      name   = var.eso_service_account_name
      annotations = {
        "azure.workload.identity/client-id" = azurerm_user_assigned_identity.eso_identity.client_id
      }
    }
    
    podLabels = {
      "azure.workload.identity/use" = "true"
    }
    
    webhook = {
      serviceAccount = {
        create = true
        name   = "${var.eso_service_account_name}-webhook"
        annotations = {
          "azure.workload.identity/client-id" = azurerm_user_assigned_identity.eso_identity.client_id
        }
      }
      podLabels = {
        "azure.workload.identity/use" = "true"
      }
    }
    
    certController = {
      serviceAccount = {
        create = true
        name   = "${var.eso_service_account_name}-cert-controller"
        annotations = {
          "azure.workload.identity/client-id" = azurerm_user_assigned_identity.eso_identity.client_id
        }
      }
      podLabels = {
        "azure.workload.identity/use" = "true"
      }
    }
  })
}

# -----------------------------------------------------------------------------
# External Secrets Operator Helm Release
# -----------------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = var.eso_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [local.eso_values]

  depends_on = [
    azurerm_user_assigned_identity.eso_identity,
    azurerm_federated_identity_credential.eso_federated_credential,
    azurerm_role_assignment.eso_keyvault_secrets_user
  ]
}
