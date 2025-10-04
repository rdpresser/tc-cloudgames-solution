variable "name_prefix" {
  description = "Name prefix for Container App Environment"
  type        = string
}

variable "location" {
  description = "Azure region where the Container App Environment will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where the Container App Environment will be deployed"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
