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
