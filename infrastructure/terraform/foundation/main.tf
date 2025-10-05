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

  elasticsearch_game_endpoint    = var.elasticsearch_game_endpoint
  elasticsearch_game_apikey      = var.elasticsearch_game_apikey
  elasticsearch_game_projectid   = var.elasticsearch_game_projectid
  elasticsearch_game_indexprefix = var.elasticsearch_game_indexprefix

  grafana_logs_api_token                    = var.grafana_logs_api_token
  grafana_otel_prometheus_api_token         = var.grafana_otel_prometheus_api_token
  grafana_otel_games_resource_attributes    = var.grafana_otel_games_resource_attributes
  grafana_otel_users_resource_attributes    = var.grafana_otel_users_resource_attributes
  grafana_otel_payments_resource_attributes = var.grafana_otel_payments_resource_attributes
  grafana_otel_exporter_endpoint            = var.grafana_otel_exporter_endpoint
  grafana_otel_exporter_protocol            = var.grafana_otel_exporter_protocol
  grafana_otel_auth_header                  = var.grafana_otel_auth_header

  sendgrid_api_key            = var.sendgrid_api_key
  sendgrid_email_new_user_tid = var.sendgrid_email_new_user_tid
  sendgrid_email_purchase_tid = var.sendgrid_email_purchase_tid

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

  # Topics e subscriptions para Azure Functions
  topics = [
    {
      name   = "user.events-topic"
      create = false # Criado via código C#
    },
    {
      name   = "game.events-topic"
      create = false # Criado via código C#
    }
  ]

  topic_subscriptions = {
    "user.events-topic" = {
      subscription_name = "welcome-subscription"
      sql_filter_rules = {
        "UserAggregateFilter" = {
          filter_expression = "DomainAggregate = 'UserAggregate'"
          action            = ""
          rule_name         = "UsersDomainAggregateFilter"
        }
      }
    }
    "game.events-topic" = {
      subscription_name = "purchase-subscription"
      sql_filter_rules = {
        "GamePurchasePaymentFilter" = {
          filter_expression = "DomainAggregate = 'GameAggregate'"
          action            = ""
          rule_name         = "GamePurchasePaymentApprovedFilter"
        }
      }
    }
  }
  create_sql_filter_rules = true

  # RBAC será configurado separadamente para evitar ciclo de dependência
  managed_identity_principal_ids = []

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# App Service Plan for Azure Functions
# =============================================================================
module "function_app_service_plan" {
  source              = "../modules/app_service_plan"
  name_prefix         = local.full_name
  service_name        = "functions-asp"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku_name            = "Y1" # Consumption plan for serverless functions
  tags                = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# Azure Function App
# =============================================================================
module "function_app" {
  source                     = "../modules/function_app"
  name_prefix                = local.full_name
  service_name               = "functions"
  location                   = module.resource_group.location
  resource_group_name        = module.resource_group.name
  app_service_plan_id        = module.function_app_service_plan.app_service_plan_id
  log_analytics_workspace_id = module.logs.log_analytics_workspace_id
  key_vault_id               = module.key_vault.key_vault_id
  key_vault_uri              = module.key_vault.key_vault_uri
  tags                       = local.common_tags

  depends_on = [
    module.resource_group,
    module.function_app_service_plan,
    module.logs,
    module.key_vault
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
# API Management Module
# =============================================================================

module "apim" {
  source              = "../modules/apim"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name

  tags = local.common_tags

  depends_on = [
    module.resource_group
  ]
}

module "apim_api" {
  source   = "../modules/apim_api"
  for_each = var.apis

  name_prefix        = each.value.name
  display_name       = each.value.display_name
  path               = each.value.path
  swagger_url        = each.value.swagger_url
  api_policy         = lookup(each.value, "api_policy", null)
  operation_policies = lookup(each.value, "operation_policies", {})

  api_management_name = module.apim.name
  resource_group_name = module.apim.resource_group_name

  depends_on = [
    module.apim
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
