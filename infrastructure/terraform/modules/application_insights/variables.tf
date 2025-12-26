// -----------------------------------------------------------------------------
// Application Insights Module - Variables
// -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for naming the Application Insights resource"
  type        = string
}

variable "location" {
  description = "Azure region for the Application Insights resource"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace for workspace-based Application Insights"
  type        = string
}

variable "sampling_percentage" {
  description = "Percentage of telemetry data to collect (0-100). 100 means no sampling."
  type        = number
  default     = 100
}

variable "daily_data_cap_in_gb" {
  description = "Daily data volume cap in GB. 0 means no cap."
  type        = number
  default     = 0
}

variable "disable_ip_masking" {
  description = "Disable IP address masking for detailed client IP tracking"
  type        = bool
  default     = false
}

variable "internet_query_enabled" {
  description = "Enable querying Application Insights from the internet (Azure Portal)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the Application Insights resource"
  type        = map(string)
  default     = {}
}
