variable "name_prefix" {
  description = "Prefix for resource names (e.g., tc-cloudgames-dev-abcd)"
  type        = string
}

variable "service_name" {
  description = "Logical service name (e.g., users-api)"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

variable "container_app_environment_id" {
  description = "Azure Container Apps Environment resource ID"
  type        = string
}

variable "location" {
  description = "Azure location (for AzAPI resource)"
  type        = string
}

variable "container_image_acr" {
  description = "Final private image to use after RBAC propagation (e.g., myacr.azurecr.io/users-api:latest)"
  type        = string
}

variable "container_image_placeholder" {
  description = "Public image used during initial creation (no ACR needed)"
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "container_registry_server" {
  description = "ACR login server (e.g., myacr.azurecr.io)"
  type        = string
}

variable "container_registry_id" {
  description = "Azure Container Registry resource ID for RBAC assignment"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault resource ID for RBAC assignment"
  type        = string
}

variable "key_vault_uri" {
  description = "Key Vault URI (e.g., https://mykv.vault.azure.net/)"
  type        = string
}

variable "target_port" {
  description = "Container port to expose"
  type        = number
  default     = 8080
}

variable "cpu_requests" {
  description = "Container CPU request"
  type        = string
  default     = "0.25"
}

variable "memory_requests" {
  description = "Container memory request"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum replicas"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "db_name_secret_ref" {
  description = "Database name secret reference (e.g., 'db-name-users', 'db-name-games', 'db-name-payments')"
  type        = string
}

variable "use_hello_world_images" {
  description = "Use hello-world public images (first deployment). When true: disables ACR and Key Vault. When false: enables full production setup."
  type        = bool
  default     = false
}

variable "enable_secrets_gradually" {
  description = "Deploy secrets gradually to avoid RBAC propagation issues. When false: no secrets. When true: all secrets."
  type        = bool
  default     = false
}

# Note: Environment variables are now configured via GitHub Actions pipeline
# using azure/container-apps-deploy-action@v2. This module creates the secret 
# bindings via System Managed Identity for Key Vault access.

variable "rbac_propagation_wait_seconds" {
  description = "Seconds to wait after RBAC assignment before patching secrets"
  type        = number
  default     = 600  # 10 minutes - Azure RBAC propagation can be slow
}

variable "timeouts_create" {
  description = "Timeout for create operations"
  type        = string
  default     = "30m"
}

variable "timeouts_update" {
  description = "Timeout for update operations"
  type        = string
  default     = "20m"
}

variable "timeouts_delete" {
  description = "Timeout for delete operations"
  type        = string
  default     = "20m"
}
