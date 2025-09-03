provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# =============================================================================
# Deployment Timing - Start Timestamp (using locals)
# =============================================================================
locals {
  deployment_start_time = timestamp()
}

# =============================================================================
# Azure Resource Provider Registration (Microsoft.App) - REMOVED
# =============================================================================
# Note: Microsoft.App provider is assumed to be already registered
# Container Apps require this provider but it's managed at subscription level
# If you get errors about Microsoft.App not being registered, run:
# az provider register --namespace Microsoft.App

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

  # Note: Microsoft.App provider dependency removed
  # Provider is assumed to be registered at subscription level
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
    module.logs
    # Note: Microsoft.App provider dependency removed
    # Provider is assumed to be registered at subscription level
  ]
}

// -----------------------------------------------------------------------------
// Key Vault Module (PURE TERRAFORM RBAC APPROACH)
// Creates: Key Vault -> RBAC Roles -> Secrets (in correct sequence)
// -----------------------------------------------------------------------------
module "key_vault" {
  source              = "../modules/key_vault"
  name_prefix         = replace(local.full_name, "-", "")
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  resource_group_id   = module.resource_group.id
  tags                = local.common_tags
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Infrastructure values to populate secrets (keeping original variable names)
  acr_name                 = module.acr.acr_name
  acr_login_server         = module.acr.acr_login_server
  acr_admin_username       = module.acr.acr_admin_username
  acr_admin_password       = module.acr.acr_admin_password
  postgres_fqdn            = module.postgres.postgres_server_fqdn
  postgres_admin_login     = var.postgres_admin_login
  postgres_admin_password  = var.postgres_admin_password
  redis_hostname           = module.redis.redis_hostname
  redis_ssl_port           = tostring(module.redis.redis_ssl_port)
  redis_primary_access_key = module.redis.redis_primary_access_key
  servicebus_namespace     = module.servicebus.namespace_name

  # Database connection info (NEW: using new variable pattern)
  db_host = module.postgres.postgres_server_fqdn
  db_port = tostring(module.postgres.postgres_port)

  # Cache connection info (NEW: using new variable pattern)
  cache_host     = module.redis.redis_hostname
  cache_port     = tostring(module.redis.redis_ssl_port)
  cache_password = module.redis.redis_primary_access_key

  # Service Bus info
  servicebus_connection_string = module.servicebus.namespace_connection_string

  # RBAC Access Control (NEW: using new variable names)
  service_principal_object_id = var.app_object_id
  user_object_id              = var.user_object_id
  github_actions_object_id    = var.github_actions_object_id
  subscription_id             = data.azurerm_client_config.current.subscription_id

  depends_on = [
    module.resource_group,
    module.acr,
    module.postgres,
    module.redis,
    module.servicebus
  ]
}

#########################################
# Service Bus module
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

#########################################
# Users API Container App module
#########################################

module "users_api_container_app" {
  source                       = "../modules/container_app"
  name_prefix                  = local.full_name
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  container_registry_server    = module.acr.acr_login_server
  key_vault_name               = module.key_vault.key_vault_name
  subscription_id              = data.azurerm_client_config.current.subscription_id
  service_name                 = "users-api"
  tags                         = local.common_tags
  db_name                      = "db-name-users"

  depends_on = [
    module.resource_group,
    module.container_app_environment,
    module.acr,
    module.key_vault
  ]
}

#########################################
# Games API Container App module
#########################################

module "games_api_container_app" {
  source                       = "../modules/container_app"
  name_prefix                  = local.full_name
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  container_registry_server    = module.acr.acr_login_server
  key_vault_name               = module.key_vault.key_vault_name
  subscription_id              = data.azurerm_client_config.current.subscription_id
  service_name                 = "games-api"
  tags                         = local.common_tags
  db_name                      = "db-name-games"

  depends_on = [
    module.resource_group,
    module.container_app_environment,
    module.acr,
    module.key_vault
  ]
}

#########################################
# Payments API Container App module
#########################################

module "payments_api_container_app" {
  source                       = "../modules/container_app"
  name_prefix                  = local.full_name
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  container_registry_server    = module.acr.acr_login_server
  key_vault_name               = module.key_vault.key_vault_name
  subscription_id              = data.azurerm_client_config.current.subscription_id
  service_name                 = "payms-api"
  tags                         = local.common_tags
  db_name                      = "db-name-payments"

  depends_on = [
    module.resource_group,
    module.container_app_environment,
    module.acr,
    module.key_vault
  ]
}

# =============================================================================
# Deployment Timing - End Timestamp and Duration Calculation
# =============================================================================
locals {
  deployment_end_time = timestamp()

  # Calculate duration in seconds (approximation since both timestamps are taken at plan time)
  # Note: This gives an estimate since both timestamps are captured during planning phase
  # For more accurate measurement, use external timing in CI/CD pipeline
  deployment_duration_estimate = "Measured by CI/CD pipeline for accurate timing"
}
