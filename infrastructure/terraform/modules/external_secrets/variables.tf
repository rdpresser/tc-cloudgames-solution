# =============================================================================
# External Secrets Operator Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# AKS Configuration
# -----------------------------------------------------------------------------

variable "aks_oidc_issuer_url" {
  description = "OIDC Issuer URL from AKS cluster"
  type        = string
}

# -----------------------------------------------------------------------------
# Key Vault Configuration
# -----------------------------------------------------------------------------

variable "key_vault_id" {
  description = "ID of the Key Vault to grant access to"
  type        = string
}

# -----------------------------------------------------------------------------
# External Secrets Operator Configuration
# -----------------------------------------------------------------------------

variable "eso_namespace" {
  description = "Kubernetes namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "Name of the ServiceAccount for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_chart_version" {
  description = "Helm chart version for External Secrets Operator"
  type        = string
  default     = "0.10.7"
}
