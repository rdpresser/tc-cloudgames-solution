# =============================================================================
# Azure Kubernetes Service (AKS) Cluster - Dev/Test Optimized
# =============================================================================

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name_prefix}-aks-dns"
  kubernetes_version  = var.kubernetes_version

  # System node pool (optimized for dev/test with autoscaling)
  # Note: In provider 4.x, you must use EITHER node_count OR (min_count + max_count)
  # Using dynamic block to avoid defining both simultaneously
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    auto_scaling_enabled         = true
    type                         = "VirtualMachineScaleSets"
    vnet_subnet_id               = var.vnet_subnet_id
    orchestrator_version         = var.kubernetes_version
    os_disk_size_gb              = var.system_node_os_disk_size_gb
    max_pods                     = var.max_pods_per_node
    only_critical_addons_enabled = var.only_critical_addons_enabled
    temporary_name_for_rotation  = "systmp"

    tags = var.tags
  }

  # System Assigned Managed Identity
  identity {
    type = "SystemAssigned"
  }

  # Network configuration - Azure CNI for VNet integration
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"

    # DNS and Service CIDR (must not overlap with VNet)
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # Enable OIDC Issuer for Workload Identity (future use)
  oidc_issuer_enabled = var.oidc_issuer_enabled

  # Enable Workload Identity (Azure AD Workload Identity)
  workload_identity_enabled = var.workload_identity_enabled

  # Monitoring (Log Analytics integration)
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Disable local accounts (enforce Azure AD authentication) - only if AD groups configured
  local_account_disabled = length(var.admin_group_object_ids) > 0 ? var.local_account_disabled : false

  tags = var.tags

  lifecycle {
    # Prevent Terraform from attempting AKS updates due to provider/API drift
    # when no IaC changes were made. Azure may auto-patch agent pool versions
    # and modify nested tags, which can trigger unwanted updates.
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version,
      default_node_pool[0].tags,
      default_node_pool[0].upgrade_settings,
    ]
  }
}
