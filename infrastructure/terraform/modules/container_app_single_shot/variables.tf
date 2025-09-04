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

variable "subscription_id" {
  description = "Subscription ID used to compute scopes for RBAC"
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

variable "key_vault_name" {
  description = "Key Vault name"
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
  default     = "0.5"
}

variable "memory_requests" {
  description = "Container memory request"
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  description = "Minimum replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum replicas"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# Map of secret name -> KeyVault secret URI (versionless)
# Example:
# {
#   db-host     = "https://kv.vault.azure.net/secrets/db-host"
#   db-port     = "https://kv.vault.azure.net/secrets/db-port"
#   db-password = "https://kv.vault.azure.net/secrets/db-password"
# }
variable "kv_secret_refs" {
  description = "Map of Container App secret names to Key Vault secret URIs"
  type        = map(string)
  default     = {}
}

# Map of environment variable -> Container App secret name
# Example:
# {
#   DB_HOST     = "db-host"
#   DB_PORT     = "db-port"
#   DB_PASSWORD = "db-password"
# }
variable "env_secret_refs" {
  description = "Map of environment variables to Container App secret names"
  type        = map(string)
  default     = {}
}

# Optional plain environment variables (non-secret)
# Example: [{ name = "ASPNETCORE_ENVIRONMENT", value = "Production" }]
variable "env_plain" {
  description = "Plain env vars (non-secret) to set on the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    { name = "ASPNETCORE_ENVIRONMENT", value = "Production" },
    { name = "ASPNETCORE_URLS",        value = "http://+:8080" }
  ]
}

# Extra wait (seconds) after RBAC to avoid AAD propagation flakiness
variable "rbac_propagation_wait_seconds" {
  description = "Seconds to wait after RBAC assignment before patching secrets"
  type        = number
  default     = 30
}
