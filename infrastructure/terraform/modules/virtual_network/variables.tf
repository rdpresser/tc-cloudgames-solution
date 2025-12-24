variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.240.0.0/16"]
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet"
  type        = list(string)
  default     = ["10.240.0.0/22"]
}

variable "service_endpoints" {
  description = "Service endpoints for the AKS subnet"
  type        = list(string)
  default = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus"
  ]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
