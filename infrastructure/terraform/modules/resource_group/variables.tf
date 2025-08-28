# Variable that defines the base prefix used for the Resource Group name
variable "name_prefix" {
  type        = string
  description = "Base prefix for the Resource Group name"
}

# Variable that defines the Azure region where the Resource Group will be created
variable "location" {
  type        = string
  description = "Azure region where the Resource Group will be created"
}

# Variable that defines the common tags applied to the Resource Group
variable "tags" {
  type        = map(string)
  description = "Common tags to apply to the Resource Group"
  default     = {}
}
