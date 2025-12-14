# =============================================================================
# NGINX Ingress Controller for AKS
# =============================================================================
# This module installs NGINX Ingress Controller via Helm
# Uses Azure Load Balancer for external traffic
# =============================================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1" # Latest 3.x
    }
  }
}

# -----------------------------------------------------------------------------
# Helm Values for NGINX Ingress Controller
# -----------------------------------------------------------------------------
locals {
  nginx_values = yamlencode({
    controller = {
      replicaCount = var.replica_count
      
      service = {
        type                  = "LoadBalancer"
        externalTrafficPolicy = "Local"
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
        }
      }
      
      metrics = {
        enabled = var.enable_metrics
        serviceMonitor = {
          enabled = var.enable_service_monitor
        }
      }
      
      podDisruptionBudget = {
        enabled      = var.enable_pdb
        minAvailable = 1
      }
      
      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }
      
      admissionWebhooks = {
        enabled = true
      }
    }
    
    defaultBackend = {
      enabled = var.enable_default_backend
    }
  })
}

# -----------------------------------------------------------------------------
# NGINX Ingress Controller Helm Release
# -----------------------------------------------------------------------------
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.nginx_chart_version
  namespace        = var.nginx_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [local.nginx_values]
}
