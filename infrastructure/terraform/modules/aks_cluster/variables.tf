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

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.33"
}

variable "vnet_subnet_id" {
  description = "ID of the subnet where AKS nodes will be deployed"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for monitoring"
  type        = string
}

# =============================================================================
# System Node Pool Configuration
# =============================================================================

variable "system_node_count" {
  description = "Number of nodes in the system node pool (used when auto-scaling is disabled)"
  type        = number
  default     = 1
}

variable "system_node_vm_size" {
  description = "VM size for system node pool (B2ms = 2 vCPU, 8 GB RAM, 1250 Mbps network - upgraded from B2s for better networking performance)"
  type        = string
  default     = "Standard_B2ms"
}

variable "system_node_os_disk_size_gb" {
  description = "OS disk size in GB for system nodes (30 GB is sufficient for dev/test)"
  type        = number
  default     = 30
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 30
}

# =============================================================================
# Auto-scaling Configuration (Cost Optimization for Dev/Test)
# =============================================================================

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for system node pool (scales nodes based on workload demand)"
  type        = bool
  default     = true
}

variable "system_node_min_count" {
  description = "Minimum number of nodes when auto-scaling is enabled (1 is minimum for system pool)"
  type        = number
  default     = 1

  validation {
    condition     = var.system_node_min_count >= 1
    error_message = "System node pool requires at least 1 node (Azure constraint)"
  }
}

variable "system_node_max_count" {
  description = "Maximum number of nodes when auto-scaling is enabled (scales up during high load)"
  type        = number
  default     = 5

  validation {
    condition     = var.system_node_max_count >= 1 && var.system_node_max_count <= 100
    error_message = "Max count must be between 1 and 100"
  }
}

# =============================================================================
# Node Pool Behavior (Dev/Test Optimization)
# =============================================================================

variable "only_critical_addons_enabled" {
  description = "Only schedule critical addons on system pool (false = allow workload pods for dev/test cost optimization)"
  type        = bool
  default     = false
}


# =============================================================================
# Network Configuration
# =============================================================================

variable "service_cidr" {
  description = "CIDR for Kubernetes services (must not overlap with VNet)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service (must be within service_cidr)"
  type        = string
  default     = "10.0.0.10"
}

# =============================================================================
# Identity and RBAC Configuration
# =============================================================================

variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer for Workload Identity"
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable Azure AD Workload Identity"
  type        = bool
  default     = true
}

variable "admin_group_object_ids" {
  description = "List of Azure AD group object IDs that will have admin access to the cluster"
  type        = list(string)
  default     = []
}

variable "local_account_disabled" {
  description = "Disable local accounts and enforce Azure AD authentication"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
