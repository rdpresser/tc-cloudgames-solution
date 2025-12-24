# =============================================================================
# NGINX Ingress Controller for AKS
# =============================================================================
# This module installs NGINX Ingress Controller via Helm
# Uses Azure Load Balancer for external traffic
# Optionally creates a static public IP
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1" # Latest 3.x
    }
  }
}

# -----------------------------------------------------------------------------
# Static Public IP for Load Balancer (optional)
# -----------------------------------------------------------------------------
resource "azurerm_public_ip" "nginx_ingress" {
  count               = var.load_balancer_ip == null && var.node_resource_group != null ? 1 : 0
  name                = "nginx-ingress-ip"
  location            = var.location
  resource_group_name = var.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Helm Values for NGINX Ingress Controller
# -----------------------------------------------------------------------------
locals {
  # Use provided IP or created IP
  nginx_lb_ip = var.load_balancer_ip != null ? var.load_balancer_ip : (
    length(azurerm_public_ip.nginx_ingress) > 0 ? azurerm_public_ip.nginx_ingress[0].ip_address : null
  )
  
  nginx_values = yamlencode({
    controller = {
      replicaCount = var.replica_count
      
      service = {
        type                  = "LoadBalancer"
        externalTrafficPolicy = "Local"
        loadBalancerIP        = local.nginx_lb_ip
        annotations = merge(
          {
            "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
          },
          local.nginx_lb_ip != null ? {
            "service.beta.kubernetes.io/azure-load-balancer-resource-group" = var.node_resource_group
          } : {}
        )
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
