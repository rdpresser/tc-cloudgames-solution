variable "container_app_name" {
  description = "Name of the existing Container App to update"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "container_image" {
  description = "Container image to use"
  type        = string
}

variable "cpu_requests" {
  description = "CPU requests for the container"
  type        = string
  default     = "0.5"
}

variable "memory_requests" {
  description = "Memory requests for the container"
  type        = string
  default     = "1.0Gi"
}

variable "key_vault_id" {
  description = "ID of the Key Vault containing secrets"
  type        = string
}

variable "db_name" {
  description = "Name of the database secret"
  type        = string
}

variable "role_assignment_dependencies" {
  description = "List of role assignment resources that must be created first"
  type        = list(any)
  default     = []
}
