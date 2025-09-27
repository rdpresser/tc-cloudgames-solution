# =============================================================================
# Elasticsearch Module Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Elasticsearch Configuration
# =============================================================================

variable "elasticsearch_cpu" {
  description = "CPU cores for Elasticsearch container"
  type        = number
  default     = 2

  validation {
    condition     = var.elasticsearch_cpu >= 1 && var.elasticsearch_cpu <= 4
    error_message = "Elasticsearch CPU must be between 1 and 4 cores."
  }
}

variable "elasticsearch_memory" {
  description = "Memory in GB for Elasticsearch container"
  type        = number
  default     = 4

  validation {
    condition     = var.elasticsearch_memory >= 2 && var.elasticsearch_memory <= 8
    error_message = "Elasticsearch memory must be between 2 and 8 GB."
  }
}

variable "elasticsearch_java_heap_size" {
  description = "Java heap size for Elasticsearch (e.g., '2g', '4g')"
  type        = string
  default     = "2g"

  validation {
    condition     = can(regex("^[0-9]+[gG]$", var.elasticsearch_java_heap_size))
    error_message = "Elasticsearch Java heap size must be in format like '2g' or '4g'."
  }
}

# =============================================================================
# Kibana Configuration
# =============================================================================

variable "enable_kibana" {
  description = "Enable Kibana container"
  type        = bool
  default     = false
}

variable "kibana_cpu" {
  description = "CPU cores for Kibana container"
  type        = number
  default     = 1

  validation {
    condition     = var.kibana_cpu >= 1 && var.kibana_cpu <= 2
    error_message = "Kibana CPU must be between 1 and 2 cores."
  }
}

variable "kibana_memory" {
  description = "Memory in GB for Kibana container"
  type        = number
  default     = 2

  validation {
    condition     = var.kibana_memory >= 1 && var.kibana_memory <= 4
    error_message = "Kibana memory must be between 1 and 4 GB."
  }
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be LRS, GRS, RAGRS, or ZRS."
  }
}

variable "storage_quota_gb" {
  description = "Storage quota in GB for Elasticsearch data"
  type        = number
  default     = 100

  validation {
    condition     = var.storage_quota_gb >= 10 && var.storage_quota_gb <= 1024
    error_message = "Storage quota must be between 10 and 1024 GB."
  }
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "enable_monitoring" {
  description = "Enable Application Insights and Log Analytics monitoring"
  type        = bool
  default     = true
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "allowed_source_ips" {
  description = "List of IP addresses allowed to access Elasticsearch"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_private_access" {
  description = "Enable private access only (disable public IP)"
  type        = bool
  default     = false
}

