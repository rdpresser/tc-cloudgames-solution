# =============================================================================
# ArgoCD Module Outputs
# =============================================================================

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "argocd_server_url" {
  description = "ArgoCD server external URL (LoadBalancer IP)"
  value = length(data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress) > 0 ? (
    data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip != null ?
    "http://${data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip}" :
    "http://${data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname}"
  ) : "Waiting for LoadBalancer IP..."
}

output "argocd_server_ip" {
  description = "ArgoCD server LoadBalancer external IP"
  value = length(data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress) > 0 ? (
    data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip != null ?
    data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].ip :
    data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname
  ) : null
}

output "argocd_server_hostname" {
  description = "ArgoCD server LoadBalancer hostname (if applicable)"
  value = length(data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress) > 0 ? (
    data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname
  ) : null
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.argocd.name
}

output "helm_release_version" {
  description = "Version of the deployed Helm chart"
  value       = helm_release.argocd.version
}

output "admin_username" {
  description = "ArgoCD admin username"
  value       = "admin"
}

output "kubectl_port_forward_command" {
  description = "Command to port-forward ArgoCD server locally"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

output "argocd_cli_login_command" {
  description = "Command to login via ArgoCD CLI (requires port-forward)"
  value       = "argocd login localhost:8080 --insecure --username admin --password <your-password>"
}
