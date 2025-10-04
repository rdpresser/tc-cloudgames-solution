variable "name_prefix" {
    description = "The name prefix for the API"
    type        = string
}

variable "display_name" {
    description = "The display name of the API"
    type        = string
}

variable "path" {
    description = "The path of the API"
    type        = string
}

variable "swagger_url" {
    description = "The URL of the Swagger documentation"
    type        = string
}

variable "api_management_name" {
    description = "The name of the API Management service"
    type        = string
}

variable "resource_group_name" {
    description = "The name of the resource group"
    type        = string
}

# Nova variável opcional: política global da API (XML)
variable "api_policy" {
  type    = string
  default = null
}

# Policies específicas de operações (mapa: operation_id → xml)
variable "operation_policies" {
  type    = map(string)
  default = {}
}
