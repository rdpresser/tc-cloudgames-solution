provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

#########################################
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
  full_name    = "${local.name_prefix}-${random_string.unique_suffix.result}"

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
  name_prefix             = local.full_name
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
  source              = "../modules/container_registry"
  name_prefix         = replace(local.full_name, "-", "")
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# Redis Cache Module
# =============================================================================
module "redis" {
  source              = "../modules/redis"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# Log Analytics Workspace Module
# =============================================================================
module "logs" {
  source              = "../modules/log_analytics"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

// -----------------------------------------------------------------------------
// Container App Environment Module
// Creates environment ready for Container Apps with System Managed Identity
// -----------------------------------------------------------------------------
module "container_app_environment" {
  source                     = "../modules/container_app_env"
  name_prefix                = local.full_name
  location                   = module.resource_group.location
  resource_group_name        = module.resource_group.name
  log_analytics_workspace_id = module.logs.log_analytics_workspace_id
  tags                       = local.common_tags

  depends_on = [
    module.resource_group,
    module.logs,
    azurerm_resource_provider_registration.app
  ]
}

// -----------------------------------------------------------------------------
// Key Vault Module  
// Creates Key Vault with RBAC and populates with infrastructure secrets
// -----------------------------------------------------------------------------
module "key_vault" {
  source              = "../modules/key_vault"
  name_prefix         = replace(local.full_name, "-", "")
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Pass infrastructure values to populate secrets
  acr_name                 = module.acr.acr_name
  acr_login_server         = module.acr.acr_login_server
  acr_admin_username       = module.acr.acr_admin_username
  acr_admin_password       = module.acr.acr_admin_password
  postgres_fqdn            = module.postgres.postgres_server_fqdn
  postgres_port            = tostring(module.postgres.postgres_port)
  postgres_admin_login     = var.postgres_admin_login
  postgres_admin_password  = var.postgres_admin_password
  redis_hostname           = module.redis.redis_hostname
  redis_ssl_port           = tostring(module.redis.redis_ssl_port)
  redis_primary_access_key = module.redis.redis_primary_access_key
  servicebus_namespace     = module.servicebus.namespace_name

  # RBAC Access Control - Object IDs for Key Vault permissions
  app_object_id            = var.app_object_id
  user_object_id           = var.user_object_id
  github_actions_object_id = var.github_actions_object_id

  depends_on = [
    module.resource_group,
    module.acr,
    module.postgres,
    module.redis,
    module.servicebus
  ]
}

#########################################
# Calls Service Bus module
#########################################

module "servicebus" {
  source              = "../modules/service_bus"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [
    module.resource_group
  ]
}
