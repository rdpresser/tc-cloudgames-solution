output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kube_config_raw" {
  description = "Raw Kubernetes config for kubectl"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "kube_admin_config_raw" {
  description = "Raw Kubernetes admin config for kubectl"
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
  sensitive   = true
}

output "kubelet_identity" {
  description = "Kubelet managed identity (used for ACR pull)"
  value = {
    client_id   = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
    object_id   = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
    user_assigned_identity_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].user_assigned_identity_id
  }
}

output "system_assigned_identity_principal_id" {
  description = "Principal ID of the System Assigned Managed Identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "system_assigned_identity_tenant_id" {
  description = "Tenant ID of the System Assigned Managed Identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "node_resource_group" {
  description = "Auto-generated resource group containing AKS cluster resources"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "kubernetes_version" {
  description = "Kubernetes version of the cluster"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint (host)"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (base64 encoded)"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive   = true
}
