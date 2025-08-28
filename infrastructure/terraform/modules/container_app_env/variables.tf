// -----------------------------------------------------------------------------
// Container App Environment module variables
// -----------------------------------------------------------------------------

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

variable "log_analytics_workspace_id" {
  description = "The Log Analytics Workspace ID associated with the Container App Environment"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
