provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# =============================================================================
# Deployment Timing - Start Timestamp
# =============================================================================
locals {
  deployment_start_time = timestamp()
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

# =============================================================================
# Container App Environment Module
# =============================================================================
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

# =============================================================================
# Key Vault Module (Terraform RBAC)
# =============================================================================
module "key_vault" {
  source              = "../modules/key_vault"
  name_prefix         = replace(local.full_name, "-", "")
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  resource_group_id   = module.resource_group.id
  tags                = local.common_tags
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Infrastructure values
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

  # Database & Cache
  db_host = module.postgres.postgres_server_fqdn
  db_port = tostring(module.postgres.postgres_port)

  cache_host     = module.redis.redis_hostname
  cache_port     = tostring(module.redis.redis_ssl_port)
  cache_password = module.redis.redis_primary_access_key

  # Service Bus info
  servicebus_connection_string = module.servicebus.namespace_connection_string
  # RBAC
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

# =============================================================================
# Service Bus module (sem RBAC inicial - será configurado depois)
# =============================================================================
module "servicebus" {
  source              = "../modules/service_bus"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  # Resources serão criados via código C# (Wolverine/MassTransit)
  # Deixando tudo opcional para que a aplicação tenha controle total
  topics                  = []
  topic_subscriptions     = {}
  create_sql_filter_rules = false

  # RBAC será configurado separadamente para evitar ciclo de dependência
  managed_identity_principal_ids = []

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# Container Apps (Single-Shot) - RBAC propagation wait aumentado para 90s
# =============================================================================
module "users_api_container_app" {
  source = "../modules/container_app_single_shot"

  name_prefix                  = local.full_name
  service_name                 = "users-api"
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  location                     = module.resource_group.location

  container_image_acr       = "${module.acr.acr_login_server}/users-api:latest"
  container_registry_server = module.acr.acr_login_server
  container_registry_id     = module.acr.acr_id

  key_vault_name = module.key_vault.key_vault_name
  key_vault_id   = module.key_vault.key_vault_id
  key_vault_uri  = module.key_vault.key_vault_uri

  tags = local.common_tags

  # Environment variables and secret refs are configured via GitHub Actions pipeline

  rbac_propagation_wait_seconds = 120

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
  location                     = module.resource_group.location

  container_image_acr       = "${module.acr.acr_login_server}/games-api:latest"
  container_registry_server = module.acr.acr_login_server
  container_registry_id     = module.acr.acr_id

  key_vault_name = module.key_vault.key_vault_name
  key_vault_id   = module.key_vault.key_vault_id
  key_vault_uri  = module.key_vault.key_vault_uri

  tags = local.common_tags

  # Environment variables and secret refs are configured via GitHub Actions pipeline

  rbac_propagation_wait_seconds = 180

  depends_on = [
    module.container_app_environment,
    module.acr,
    module.key_vault,
    module.postgres
  ]
}

module "payments_api_container_app" {
  source = "../modules/container_app_single_shot"

  name_prefix                  = local.full_name
  service_name                 = "payms-api"
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.container_app_environment_id
  location                     = module.resource_group.location

  container_image_acr       = "${module.acr.acr_login_server}/payments-api:latest"
  container_registry_server = module.acr.acr_login_server
  container_registry_id     = module.acr.acr_id

  key_vault_name = module.key_vault.key_vault_name
  key_vault_id   = module.key_vault.key_vault_id
  key_vault_uri  = module.key_vault.key_vault_uri

  tags = local.common_tags

  # Environment variables and secret refs are configured via GitHub Actions pipeline
  # using azure/container-apps-deploy-action@v2 with secretref pattern

  rbac_propagation_wait_seconds = 180

  depends_on = [
    module.container_app_environment,
    module.acr,
    module.key_vault,
    module.postgres
  ]
}

# =============================================================================
# Service Bus RBAC: Azure Service Bus Data Owner para Container Apps
# =============================================================================
resource "azurerm_role_assignment" "users_api_servicebus_owner" {
  principal_id         = module.users_api_container_app.system_assigned_identity_principal_id
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = module.servicebus.namespace_id

  depends_on = [
    module.servicebus,
    module.users_api_container_app
  ]
}

resource "azurerm_role_assignment" "games_api_servicebus_owner" {
  principal_id         = module.games_api_container_app.system_assigned_identity_principal_id
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = module.servicebus.namespace_id

  depends_on = [
    module.servicebus,
    module.games_api_container_app
  ]
}

resource "azurerm_role_assignment" "payments_api_servicebus_owner" {
  principal_id         = module.payments_api_container_app.system_assigned_identity_principal_id
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = module.servicebus.namespace_id

  depends_on = [
    module.servicebus,
    module.payments_api_container_app
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
