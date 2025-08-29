# ===================================================================================================
# Container App Terraform Module
# Creates individual Container Apps with System Managed Identity and Key Vault integration
# ===================================================================================================

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "container_app_environment_id" {
  description = "Container App Environment resource ID"
  type        = string
}

variable "container_registry_server" {
  description = "Container registry login server"
  type        = string
}

variable "container_image" {
  description = "Container image URI"
  type        = string
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "service_name" {
  description = "Name of the service (e.g., users-api, games-api)"
  type        = string
}

variable "target_port" {
  description = "Port that the container listens on"
  type        = number
  default     = 8080
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 10
}

variable "cpu_requests" {
  description = "CPU requests in cores"
  type        = string
  default     = "0.25"
}

variable "memory_requests" {
  description = "Memory requests"
  type        = string
  default     = "0.5Gi"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "key_vault_name" {
  description = "Name of the Key Vault for secret references"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container app"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
