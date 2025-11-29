# =============================================================================
# ArgoCD Module Variables
# =============================================================================

variable "cluster_name" {
  description = "Name of the AKS cluster where ArgoCD will be installed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the AKS cluster"
  type        = string
}

variable "admin_password" {
  description = "ArgoCD admin password (will be bcrypt hashed)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "ArgoCD admin password must be at least 8 characters long"
  }
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.0" # Latest stable as of Nov 2024
}

variable "labels" {
  description = "Additional labels to apply to ArgoCD resources"
  type        = map(string)
  default     = {}
}
