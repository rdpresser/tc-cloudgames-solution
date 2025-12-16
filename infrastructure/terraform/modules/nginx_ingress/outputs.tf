# =============================================================================
# NGINX Ingress Controller Outputs
# =============================================================================

output "nginx_namespace" {
  description = "Kubernetes namespace where NGINX Ingress is installed"
  value       = var.nginx_namespace
}

output "nginx_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.nginx_ingress.name
}

output "nginx_chart_version" {
  description = "Version of the NGINX Ingress Helm chart"
  value       = var.nginx_chart_version
}

output "load_balancer_ip" {
  description = "Static IP address of the Load Balancer"
  value       = local.nginx_lb_ip
}

output "public_ip_id" {
  description = "Resource ID of the static public IP (if created)"
  value       = length(azurerm_public_ip.nginx_ingress) > 0 ? azurerm_public_ip.nginx_ingress[0].id : null
}
