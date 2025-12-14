# =============================================================================
# Terraform Configuration
# =============================================================================
terraform {
  required_version = ">= 1.14"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56" # Latest 4.x
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.8" # Latest 2.x
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7" # Latest 3.x
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13" # Latest 0.x
    }
    # NOTE: Helm and Kubernetes providers removed.
    # ArgoCD is now installed manually via install-argocd-aks.ps1 script.
    # This avoids Terraform Cloud connectivity issues with AKS cluster.
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
