# =============================================================================
# Terraform Configuration
# =============================================================================
terraform {
  required_version = ">= 1.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.52" # Latest 4.x
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.7" # Latest 2.x
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7" # Latest 3.x
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13" # Latest 0.x
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

  # Terraform Cloud backend configuration
  cloud {
    organization = "rdpresser_tccloudgames_fiap"
    workspaces {
      name = "tc-cloudgames-foundation-dev"
    }
  }
}

# =============================================================================
# Azure Provider
# =============================================================================
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# =============================================================================
# Helm Provider (for ArgoCD installation)
# =============================================================================
# Helm provider uses data source to fetch AKS credentials dynamically.
# This allows installation of ArgoCD after AKS is created in the same apply.
#
# Note: The kubernetes attribute is a nested object (not a block) in Helm v3.
# VS Code linter may show a warning, but terraform validate passes correctly.

provider "helm" {
  kubernetes = {
    host                   = try(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].host, "")
    client_certificate     = try(base64decode(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].client_certificate), "")
    client_key             = try(base64decode(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].client_key), "")
    cluster_ca_certificate = try(base64decode(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].cluster_ca_certificate), "")
  }
}

# =============================================================================
# Kubernetes Provider (for ArgoCD namespace and resources)
# =============================================================================
# Kubernetes provider uses data source to fetch AKS credentials dynamically.
# This allows creation of namespaces and resources after AKS is created in the same apply.

provider "kubernetes" {
  host                   = try(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].host, "")
  client_certificate     = try(base64decode(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].client_certificate), null)
  client_key             = try(base64decode(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].client_key), null)
  cluster_ca_certificate = try(base64decode(data.azurerm_kubernetes_cluster.aks_for_argocd[0].kube_config[0].cluster_ca_certificate), null)
}
