provider "azurerm" {
  features {
    # Outras configurações do provider
  }
}

data "azurerm_client_config" "current" {}

# =============================================================================
# Deployment Timing - Start Timestamp (using locals)
# =============================================================================
locals {
  deployment_start_time = timestamp()
}

# =============================================================================
# Azure Resource Provider Registration (Microsoft.App) - Automatic
# =============================================================================
# Provider azurerm automatically registers required providers when creating resources
# No manual registration needed for Microsoft.App

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
# Container Apps with Single Shot Configuration
# Using new single shot module with AzAPI PATCH
#########################################

module "users_api_container_app" {
  source = "../modules/container_app_single_shot"

  name_prefix                  = local.full_name
  service_name                 = "users-api"
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  subscription_id              = data.azurerm_client_config.current.subscription_id
  location                     = module.resource_group.location

  container_image_acr       = "${module.acr.acr_login_server}/users-api:latest"
  container_registry_server = module.acr.acr_login_server

  key_vault_name = module.key_vault.key_vault_name
  key_vault_uri  = module.key_vault.key_vault_uri

  tags = local.common_tags

  # map: secret name (as it will appear in the Container App) -> KeyVault secret URI
  kv_secret_refs = {
    db-host                          = "${module.key_vault.key_vault_uri}secrets/db-host"
    db-port                          = "${module.key_vault.key_vault_uri}secrets/db-port"
    db-name-users                    = "${module.key_vault.key_vault_uri}secrets/db-name-users"
    db-admin-login                   = "${module.key_vault.key_vault_uri}secrets/db-admin-login"
    db-password                      = "${module.key_vault.key_vault_uri}secrets/db-password"
    db-name-maintenance              = "${module.key_vault.key_vault_uri}secrets/db-name-maintenance"
    db-schema                        = "${module.key_vault.key_vault_uri}secrets/db-schema"
    db-connection-timeout            = "${module.key_vault.key_vault_uri}secrets/db-connection-timeout"
    cache-host                       = "${module.key_vault.key_vault_uri}secrets/cache-host"
    cache-port                       = "${module.key_vault.key_vault_uri}secrets/cache-port"
    cache-password                   = "${module.key_vault.key_vault_uri}secrets/cache-password"
    cache-secure                     = "${module.key_vault.key_vault_uri}secrets/cache-secure"
    servicebus-connection-string     = "${module.key_vault.key_vault_uri}secrets/servicebus-connection-string"
    servicebus-auto-provision        = "${module.key_vault.key_vault_uri}secrets/servicebus-auto-provision"
    servicebus-max-delivery-count    = "${module.key_vault.key_vault_uri}secrets/servicebus-max-delivery-count"
    servicebus-enable-dead-lettering = "${module.key_vault.key_vault_uri}secrets/servicebus-enable-dead-lettering"
    servicebus-auto-purge-on-startup = "${module.key_vault.key_vault_uri}secrets/servicebus-auto-purge-on-startup"
    servicebus-use-control-queues    = "${module.key_vault.key_vault_uri}secrets/servicebus-use-control-queues"
  }

  # map: env var -> secret name (must match keys of kv_secret_refs)
  env_secret_refs = {
    DB_HOST                                = "db-host"
    DB_PORT                                = "db-port"
    DB_NAME                                = "db-name-users"
    DB_USER                                = "db-admin-login"
    DB_PASSWORD                            = "db-password"
    DB_MAINTENANCE_NAME                    = "db-name-maintenance"
    DB_SCHEMA                              = "db-schema"
    DB_CONNECTION_TIMEOUT                  = "db-connection-timeout"
    CACHE_HOST                             = "cache-host"
    CACHE_PORT                             = "cache-port"
    CACHE_PASSWORD                         = "cache-password"
    CACHE_SECURE                           = "cache-secure"
    AZURE_SERVICEBUS_CONNECTIONSTRING      = "servicebus-connection-string"
    AZURE_SERVICEBUS_AUTO_PROVISION        = "servicebus-auto-provision"
    AZURE_SERVICEBUS_MAX_DELIVERY_COUNT    = "servicebus-max-delivery-count"
    AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING = "servicebus-enable-dead-lettering"
    AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP = "servicebus-auto-purge-on-startup"
    AZURE_SERVICEBUS_USE_CONTROL_QUEUES    = "servicebus-use-control-queues"
  }

  rbac_propagation_wait_seconds = 45

  depends_on = [

    module.container_app_environment,
    module.acr,
    module.key_vault,
    module.postgres,
    module.redis,
    module.servicebus
  ]
}

module "games_api_container_app" {
  source = "../modules/container_app_single_shot"

  name_prefix                  = local.full_name
  service_name                 = "games-api"
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  subscription_id              = data.azurerm_client_config.current.subscription_id
  location                     = module.resource_group.location

  container_image_acr       = "${module.acr.acr_login_server}/games-api:latest"
  container_registry_server = module.acr.acr_login_server

  key_vault_name = module.key_vault.key_vault_name
  key_vault_uri  = module.key_vault.key_vault_uri

  tags = local.common_tags

  # map: secret name (as it will appear in the Container App) -> KeyVault secret URI
  kv_secret_refs = {
    db-host                          = "${module.key_vault.key_vault_uri}secrets/db-host"
    db-port                          = "${module.key_vault.key_vault_uri}secrets/db-port"
    db-name-games                    = "${module.key_vault.key_vault_uri}secrets/db-name-games"
    db-admin-login                   = "${module.key_vault.key_vault_uri}secrets/db-admin-login"
    db-password                      = "${module.key_vault.key_vault_uri}secrets/db-password"
    db-name-maintenance              = "${module.key_vault.key_vault_uri}secrets/db-name-maintenance"
    db-schema                        = "${module.key_vault.key_vault_uri}secrets/db-schema"
    db-connection-timeout            = "${module.key_vault.key_vault_uri}secrets/db-connection-timeout"
    cache-host                       = "${module.key_vault.key_vault_uri}secrets/cache-host"
    cache-port                       = "${module.key_vault.key_vault_uri}secrets/cache-port"
    cache-password                   = "${module.key_vault.key_vault_uri}secrets/cache-password"
    cache-secure                     = "${module.key_vault.key_vault_uri}secrets/cache-secure"
    servicebus-connection-string     = "${module.key_vault.key_vault_uri}secrets/servicebus-connection-string"
    servicebus-auto-provision        = "${module.key_vault.key_vault_uri}secrets/servicebus-auto-provision"
    servicebus-max-delivery-count    = "${module.key_vault.key_vault_uri}secrets/servicebus-max-delivery-count"
    servicebus-enable-dead-lettering = "${module.key_vault.key_vault_uri}secrets/servicebus-enable-dead-lettering"
    servicebus-auto-purge-on-startup = "${module.key_vault.key_vault_uri}secrets/servicebus-auto-purge-on-startup"
    servicebus-use-control-queues    = "${module.key_vault.key_vault_uri}secrets/servicebus-use-control-queues"
  }

  # map: env var -> secret name (must match keys of kv_secret_refs)
  env_secret_refs = {
    DB_HOST                                = "db-host"
    DB_PORT                                = "db-port"
    DB_NAME                                = "db-name-games"
    DB_USER                                = "db-admin-login"
    DB_PASSWORD                            = "db-password"
    DB_MAINTENANCE_NAME                    = "db-name-maintenance"
    DB_SCHEMA                              = "db-schema"
    DB_CONNECTION_TIMEOUT                  = "db-connection-timeout"
    CACHE_HOST                             = "cache-host"
    CACHE_PORT                             = "cache-port"
    CACHE_PASSWORD                         = "cache-password"
    CACHE_SECURE                           = "cache-secure"
    AZURE_SERVICEBUS_CONNECTIONSTRING      = "servicebus-connection-string"
    AZURE_SERVICEBUS_AUTO_PROVISION        = "servicebus-auto-provision"
    AZURE_SERVICEBUS_MAX_DELIVERY_COUNT    = "servicebus-max-delivery-count"
    AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING = "servicebus-enable-dead-lettering"
    AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP = "servicebus-auto-purge-on-startup"
    AZURE_SERVICEBUS_USE_CONTROL_QUEUES    = "servicebus-use-control-queues"
  }

  rbac_propagation_wait_seconds = 45

  depends_on = [

    module.container_app_environment,
    module.acr,
    module.key_vault,
    module.postgres,
    module.redis,
    module.servicebus
  ]
}

module "payments_api_container_app" {
  source = "../modules/container_app_single_shot"

  name_prefix                  = local.full_name
  service_name                 = "payms-api"
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  subscription_id              = data.azurerm_client_config.current.subscription_id
  location                     = module.resource_group.location

  container_image_acr       = "${module.acr.acr_login_server}/payments-api:latest"
  container_registry_server = module.acr.acr_login_server

  key_vault_name = module.key_vault.key_vault_name
  key_vault_uri  = module.key_vault.key_vault_uri

  tags = local.common_tags

  # map: secret name (as it will appear in the Container App) -> KeyVault secret URI
  kv_secret_refs = {
    db-host                          = "${module.key_vault.key_vault_uri}secrets/db-host"
    db-port                          = "${module.key_vault.key_vault_uri}secrets/db-port"
    db-name-payments                 = "${module.key_vault.key_vault_uri}secrets/db-name-payments"
    db-admin-login                   = "${module.key_vault.key_vault_uri}secrets/db-admin-login"
    db-password                      = "${module.key_vault.key_vault_uri}secrets/db-password"
    db-name-maintenance              = "${module.key_vault.key_vault_uri}secrets/db-name-maintenance"
    db-schema                        = "${module.key_vault.key_vault_uri}secrets/db-schema"
    db-connection-timeout            = "${module.key_vault.key_vault_uri}secrets/db-connection-timeout"
    cache-host                       = "${module.key_vault.key_vault_uri}secrets/cache-host"
    cache-port                       = "${module.key_vault.key_vault_uri}secrets/cache-port"
    cache-password                   = "${module.key_vault.key_vault_uri}secrets/cache-password"
    cache-secure                     = "${module.key_vault.key_vault_uri}secrets/cache-secure"
    servicebus-connection-string     = "${module.key_vault.key_vault_uri}secrets/servicebus-connection-string"
    servicebus-auto-provision        = "${module.key_vault.key_vault_uri}secrets/servicebus-auto-provision"
    servicebus-max-delivery-count    = "${module.key_vault.key_vault_uri}secrets/servicebus-max-delivery-count"
    servicebus-enable-dead-lettering = "${module.key_vault.key_vault_uri}secrets/servicebus-enable-dead-lettering"
    servicebus-auto-purge-on-startup = "${module.key_vault.key_vault_uri}secrets/servicebus-auto-purge-on-startup"
    servicebus-use-control-queues    = "${module.key_vault.key_vault_uri}secrets/servicebus-use-control-queues"
  }

  # map: env var -> secret name (must match keys of kv_secret_refs)
  env_secret_refs = {
    DB_HOST                                = "db-host"
    DB_PORT                                = "db-port"
    DB_NAME                                = "db-name-payments"
    DB_USER                                = "db-admin-login"
    DB_PASSWORD                            = "db-password"
    DB_MAINTENANCE_NAME                    = "db-name-maintenance"
    DB_SCHEMA                              = "db-schema"
    DB_CONNECTION_TIMEOUT                  = "db-connection-timeout"
    CACHE_HOST                             = "cache-host"
    CACHE_PORT                             = "cache-port"
    CACHE_PASSWORD                         = "cache-password"
    CACHE_SECURE                           = "cache-secure"
    AZURE_SERVICEBUS_CONNECTIONSTRING      = "servicebus-connection-string"
    AZURE_SERVICEBUS_AUTO_PROVISION        = "servicebus-auto-provision"
    AZURE_SERVICEBUS_MAX_DELIVERY_COUNT    = "servicebus-max-delivery-count"
    AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING = "servicebus-enable-dead-lettering"
    AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP = "servicebus-auto-purge-on-startup"
    AZURE_SERVICEBUS_USE_CONTROL_QUEUES    = "servicebus-use-control-queues"
  }

  rbac_propagation_wait_seconds = 45

  depends_on = [

    module.container_app_environment,
    module.acr,
    module.key_vault,
    module.postgres,
    module.redis,
    module.servicebus
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
