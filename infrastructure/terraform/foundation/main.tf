provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# =============================================================================
# Azure Resource Provider Registration (Microsoft.App)
# =============================================================================
resource "azurerm_resource_provider_registration" "app" {
  name = "Microsoft.App"
}

# =============================================================================
# Random suffix for unique naming
# =============================================================================
resource "random_string" "unique_suffix" {
  length  = 4
  upper   = false
  special = false
}

# =============================================================================
# Locals: naming and common tags
# =============================================================================
locals {
  environment  = var.environment
  project_name = var.project_name
  name_prefix  = "${local.project_name}-${local.environment}"

  kv_name = "tccloudgames${local.environment}kv${random_string.unique_suffix.result}"

  common_tags = {
    Environment = local.environment
    Project     = "TC Cloud Games"
    ManagedBy   = "Terraform"
    Owner       = "DevOps Team"
    CostCenter  = "Engineering"
    Workspace   = terraform.workspace
    Provider    = "Azure"
    DeployTime  = timeadd(timestamp(), "-3h") # UTC-3
  }
}

# =============================================================================
# Resource Group
# =============================================================================
module "resource_group" {
  source      = "../modules/resource_group"
  name_prefix = "${local.project_name}-solution-${local.environment}-rg"
  location    = var.azure_resource_group_location
  tags        = local.common_tags

  depends_on = [
    azurerm_resource_provider_registration.app
  ]
}

# =============================================================================
# PostgreSQL Flexible Server
# =============================================================================

module "postgres" {
  source                  = "../modules/postgres"
  name_prefix             = "${local.name_prefix}-db-${random_string.unique_suffix.result}"
  location                = module.resource_group.location
  resource_group_name     = module.resource_group.name
  postgres_admin_login    = var.postgres_admin_login
  postgres_admin_password = var.postgres_admin_password
  tags                    = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# Azure Container Registry (ACR) Module
# =============================================================================
module "acr" {
  source = "../modules/container_registry"
  # Name prefix: local.name_prefix + "-acr-" + random suffix, with dashes removed
  name_prefix = replace("${local.name_prefix}-acr-${random_string.unique_suffix.result}", "-", "")

  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku                 = "Standard"
  admin_enabled       = true
  tags                = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

