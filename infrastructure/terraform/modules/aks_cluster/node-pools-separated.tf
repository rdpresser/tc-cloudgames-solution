# =============================================================================
# AKS Node Pools - Separated System and Workload Pools
# =============================================================================
# This configuration creates separate node pools for system components and workloads
# to ensure ArgoCD and critical services remain stable during load tests.
# =============================================================================

# System Node Pool - For Kubernetes system components + ArgoCD
resource "azurerm_kubernetes_cluster_node_pool" "system_pool" {
  name                  = "systempool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.system_pool_vm_size
  node_count           = var.system_pool_node_count
  min_count            = var.system_pool_enable_auto_scaling ? var.system_pool_min_count : null
  max_count            = var.system_pool_enable_auto_scaling ? var.system_pool_max_count : null
  auto_scaling_enabled = var.system_pool_enable_auto_scaling
  
  mode = "System"  # Dedicated for system pods
  
  vnet_subnet_id       = var.vnet_subnet_id
  orchestrator_version = var.kubernetes_version
  os_disk_size_gb     = var.system_pool_os_disk_size_gb
  max_pods            = var.max_pods_per_node
  
  node_labels = {
    "workload-type" = "system"
    "pool"          = "system"
  }
  
  node_taints = [
    "CriticalAddonsOnly=true:NoSchedule"  # Only system pods can schedule here
  ]
  
  tags = merge(
    var.tags,
    {
      Purpose = "System Components"
    }
  )
  
  lifecycle {
    ignore_changes = [
      node_count,
      orchestrator_version,
      tags,
    ]
  }
}

# Workload Node Pool - For application services (users, games, payments)
resource "azurerm_kubernetes_cluster_node_pool" "workload_pool" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size              = var.workload_pool_vm_size
  node_count           = var.workload_pool_node_count
  min_count            = var.workload_pool_enable_auto_scaling ? var.workload_pool_min_count : null
  max_count            = var.workload_pool_enable_auto_scaling ? var.workload_pool_max_count : null
  auto_scaling_enabled = var.workload_pool_enable_auto_scaling
  
  mode = "User"  # Workload pods
  
  vnet_subnet_id       = var.vnet_subnet_id
  orchestrator_version = var.kubernetes_version
  os_disk_size_gb     = var.workload_pool_os_disk_size_gb
  max_pods            = var.max_pods_per_node
  
  node_labels = {
    "workload-type" = "application"
    "pool"          = "workload"
  }
  
  tags = merge(
    var.tags,
    {
      Purpose = "Application Workloads"
    }
  )
  
  lifecycle {
    ignore_changes = [
      node_count,
      orchestrator_version,
      tags,
    ]
  }
}

# =============================================================================
# Node Pool Strategy:
# - System Pool: 2-3 nodes for ArgoCD, CoreDNS, metrics-server, kube-system
#   * Tainted to prevent workload scheduling
#   * Smaller max size to control costs
# - Workload Pool: 2-6 nodes for user/games/payments APIs
#   * Higher max allows scaling during tests without impacting ArgoCD
#   * No taints - accepts all application pods
# =============================================================================
