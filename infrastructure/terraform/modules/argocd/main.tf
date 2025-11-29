# =============================================================================
# ArgoCD Installation via Helm
# =============================================================================
# This module installs ArgoCD on an AKS cluster using the Helm provider.
# ArgoCD is deployed in the 'argocd' namespace with LoadBalancer service type.
#
# NOTE: This module expects providers to be configured by the caller (parent module).
# The AKS cluster MUST exist before this module runs (use depends_on).

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.52" # Latest 4.x
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1" # Latest 3.x
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38" # Latest 2.x
    }
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = "~> 0.1" # Latest 0.x
    }
  }
}
# =============================================================================
# Values for ArgoCD Helm Chart (Helm v3: consolidate overrides via values)
# =============================================================================
locals {
  argocd_values = yamlencode({
    server = {
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
        }
      }
      ingress   = { enabled = false }
      # Easier access for dev (no TLS). For prod, prefer TLS enabled.
      extraArgs = ["--insecure"]
      resources = {
        limits = { cpu = "500m",  memory = "512Mi" }
        requests = { cpu = "250m", memory = "256Mi" }
      }
    }
    controller = {
      resources = {
        limits = { cpu = "1000m", memory = "1Gi" }
      }
    }
    repoServer = {
      resources = {
        limits = { cpu = "500m", memory = "512Mi" }
      }
    }
    configs = {
      secret = {
        argocdServerAdminPassword = bcrypt_hash.argocd_admin_password.id
      }
    }
    global = {
      labels = var.labels
    }
  })
}

# =============================================================================
# Data Source: Fetch AKS cluster credentials
# =============================================================================
# This data source retrieves the existing AKS cluster configuration.
# The cluster must exist before this module is applied.
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

# =============================================================================
# Namespace for ArgoCD
# =============================================================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }
}

# =============================================================================
# Generate bcrypt hash for admin password
# =============================================================================
# ArgoCD stores passwords as bcrypt hashes in the argocd-secret
resource "bcrypt_hash" "argocd_admin_password" {
  cleartext = var.admin_password
  cost      = 10
}

# =============================================================================
# ArgoCD Helm Release
# =============================================================================
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Helm v3 style: pass all overrides as values YAML
  values = [local.argocd_values]

  depends_on = [
    kubernetes_namespace.argocd
  ]

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes
}

# =============================================================================
# Wait for LoadBalancer to get external IP
# =============================================================================
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [
    helm_release.argocd
  ]
}
