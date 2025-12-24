data "azurerm_client_config" "current" {}

# ArgoCD installed via: infrastructure/kubernetes/scripts/azure/aks-manager.ps1 install-argocd

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

  # Force application pool sizes in code to override workspace defaults
  db_max_pool_size = 20
  db_min_pool_size = 2
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
  postgres_sku            = var.postgres_sku
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
# Virtual Network Module (for AKS)
# =============================================================================
module "vnet" {
  source              = "../modules/virtual_network"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  # Default: 10.240.0.0/16 for VNet, 10.240.0.0/22 for AKS subnet
  # Can be overridden via variables if needed

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# AKS Cluster Module
# =============================================================================
module "aks" {
  source              = "../modules/aks_cluster"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  kubernetes_version  = var.kubernetes_version

  # Network configuration
  vnet_subnet_id = module.vnet.aks_subnet_id

  # Monitoring
  log_analytics_workspace_id = module.logs.log_analytics_workspace_id

  # System node pool configuration (optimized for dev/test with autoscaling)
  system_node_count     = var.aks_system_node_count
  system_node_vm_size   = var.aks_system_node_vm_size
  enable_auto_scaling   = var.aks_enable_auto_scaling
  system_node_min_count = var.aks_system_node_min_count
  system_node_max_count = var.aks_system_node_max_count

  # RBAC configuration
  admin_group_object_ids = var.aks_admin_group_object_ids

  tags = local.common_tags

  depends_on = [
    module.resource_group,
    module.vnet,
    module.logs
  ]
}

# =============================================================================
# ACR Pull Permission for AKS
# =============================================================================
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = module.aks.kubelet_identity.object_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id

  depends_on = [
    module.aks,
    module.acr
  ]
}

# =============================================================================
# NGINX Ingress Controller with Static IP
# =============================================================================
# NGINX Ingress instalado manualmente via script PowerShell
# Ver: infrastructure/kubernetes/scripts/prod/install-nginx-ingress-aks.ps1
# Motivo: Terraform Cloud não tem acesso ao cluster Kubernetes
#
# module "nginx_ingress" {
#   source              = "../modules/nginx_ingress"
#   location            = module.resource_group.location
#   node_resource_group = module.aks.node_resource_group
#
#   # Static IP will be created automatically
#   load_balancer_ip = null # Let module create it
#
#   replica_count = 2
#
#   enable_metrics         = true
#   enable_service_monitor = false
#   enable_pdb             = true
#   enable_default_backend = true
#
#   tags = local.common_tags
#
#   depends_on = [
#     module.aks,
#     azurerm_role_assignment.aks_acr_pull
#   ]
# }

# ArgoCD installed via: aks-manager.ps1 install-argocd

# Grafana Agent installed via: aks-manager.ps1 install-grafana-agent

# =============================================================================
# User-Assigned Identities for Workload Identity (Applications)
# =============================================================================
# Each application gets its own managed identity for Azure service authentication
# These identities are federated with Kubernetes ServiceAccounts via OIDC
resource "azurerm_user_assigned_identity" "user_api" {
  name                = "${local.full_name}-user-api-identity"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [module.aks]
}

resource "azurerm_user_assigned_identity" "games_api" {
  name                = "${local.full_name}-games-api-identity"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [module.aks]
}

resource "azurerm_user_assigned_identity" "payments_api" {
  name                = "${local.full_name}-payments-api-identity"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  depends_on = [module.aks]
}

# =============================================================================
# Federated Identity Credentials for Workload Identity
# =============================================================================
# Links Azure AD managed identities to Kubernetes ServiceAccounts via OIDC
# This enables pods to authenticate to Azure services without secrets
resource "azurerm_federated_identity_credential" "user_api" {
  name                = "${local.full_name}-user-api-fic"
  resource_group_name = module.resource_group.name
  parent_id           = azurerm_user_assigned_identity.user_api.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  subject             = "system:serviceaccount:cloudgames:user-api-sa"

  depends_on = [azurerm_user_assigned_identity.user_api]
}

resource "azurerm_federated_identity_credential" "games_api" {
  name                = "${local.full_name}-games-api-fic"
  resource_group_name = module.resource_group.name
  parent_id           = azurerm_user_assigned_identity.games_api.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  subject             = "system:serviceaccount:cloudgames:games-api-sa"

  depends_on = [azurerm_user_assigned_identity.games_api]
}

resource "azurerm_federated_identity_credential" "payments_api" {
  name                = "${local.full_name}-payments-api-fic"
  resource_group_name = module.resource_group.name
  parent_id           = azurerm_user_assigned_identity.payments_api.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  subject             = "system:serviceaccount:cloudgames:payments-api-sa"

  depends_on = [azurerm_user_assigned_identity.payments_api]
}

# =============================================================================
# Log Analytics Workspace Module
# =============================================================================
module "logs" {
  source              = "../modules/log_analytics"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  daily_quota_gb      = var.log_analytics_daily_quota_gb
  tags                = local.common_tags

  depends_on = [
    module.resource_group
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

  # App DB pool sizes (forced to 20/2 via locals to avoid workspace overrides)
  db_max_pool_size      = local.db_max_pool_size
  db_min_pool_size      = local.db_min_pool_size
  db_connection_timeout = 60

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
      create = false
    },
    {
      name   = "game.events-topic"
      create = false
    },
    # {
    #   name   = "payment.events-topic"
    #   create = true
    # }
  ]

  topic_subscriptions = {
    # "user.events-topic.games" = {
    #   topic_name        = "user.events-topic"
    #   subscription_name = "games.user.events-subscription"
    #   sql_filter_rules = {
    #     "UserAggregateFilter" = {
    #       filter_expression = "DomainAggregate = 'UserAggregate'"
    #       action            = ""
    #       rule_name         = "UsersDomainAggregateFilter"
    #     }
    #   }
    # }
    "user.events-topic.welcome" = {
      topic_name        = "user.events-topic"
      subscription_name = "welcome-subscription"
      sql_filter_rules = {
        "UserAggregateFilter" = {
          filter_expression = "DomainAggregate = 'UserAggregate'"
          action            = ""
          rule_name         = "WelcomeUserCreatedFilter"
        }
      }
    }
    # "game.events-topic.payments" = {
    #   topic_name        = "game.events-topic"
    #   subscription_name = "payments.game.events-subscription"
    #   sql_filter_rules = {
    #     "GameAggregateFilter" = {
    #       filter_expression = "DomainAggregate = 'GameAggregate'"
    #       action            = ""
    #       rule_name         = "GamesDomainAggregateFilter"
    #     }
    #   }
    # }
    "game.events-topic.purchase" = {
      topic_name        = "game.events-topic"
      subscription_name = "purchase-subscription"
      sql_filter_rules = {
        "GamePurchasePaymentFilter" = {
          filter_expression = "DomainAggregate = 'GameAggregate'"
          action            = ""
          rule_name         = "GamePurchasePaymentApprovedFilter"
        }
      }
    }
    # "payment.events-topic.games" = {
    #   topic_name        = "payment.events-topic"
    #   subscription_name = "games.payment.events-subscription"
    #   sql_filter_rules = {
    #     "PaymentAggregateFilter" = {
    #       filter_expression = "DomainAggregate = 'PaymentAggregate'"
    #       action            = ""
    #       rule_name         = "PaymentsDomainAggregateFilter"
    #     }
    #   }
    # }
  }
  create_sql_filter_rules = true

  # RBAC: Atribuir Azure Service Bus Data Owner às Managed Identities das APIs
  managed_identity_principal_ids = [
    azurerm_user_assigned_identity.user_api.principal_id,
    azurerm_user_assigned_identity.games_api.principal_id,
    azurerm_user_assigned_identity.payments_api.principal_id
  ]

  depends_on = [
    module.resource_group
  ]
}

# =============================================================================
# Service Bus RBAC for Workload Identity (Applications)
# =============================================================================
# Grant minimum required permissions: Data Sender + Data Receiver
# Each application can send and receive messages from Service Bus topics/queues

# User API - Azure Service Bus Data Sender
resource "azurerm_role_assignment" "user_api_sb_sender" {
  principal_id         = azurerm_user_assigned_identity.user_api.principal_id
  role_definition_name = "Azure Service Bus Data Sender"
  scope                = module.servicebus.namespace_id

  depends_on = [
    azurerm_user_assigned_identity.user_api,
    module.servicebus
  ]
}

# User API - Azure Service Bus Data Receiver
resource "azurerm_role_assignment" "user_api_sb_receiver" {
  principal_id         = azurerm_user_assigned_identity.user_api.principal_id
  role_definition_name = "Azure Service Bus Data Receiver"
  scope                = module.servicebus.namespace_id

  depends_on = [
    azurerm_user_assigned_identity.user_api,
    module.servicebus
  ]
}

# Games API - Azure Service Bus Data Sender
resource "azurerm_role_assignment" "games_api_sb_sender" {
  principal_id         = azurerm_user_assigned_identity.games_api.principal_id
  role_definition_name = "Azure Service Bus Data Sender"
  scope                = module.servicebus.namespace_id

  depends_on = [
    azurerm_user_assigned_identity.games_api,
    module.servicebus
  ]
}

# Games API - Azure Service Bus Data Receiver
resource "azurerm_role_assignment" "games_api_sb_receiver" {
  principal_id         = azurerm_user_assigned_identity.games_api.principal_id
  role_definition_name = "Azure Service Bus Data Receiver"
  scope                = module.servicebus.namespace_id

  depends_on = [
    azurerm_user_assigned_identity.games_api,
    module.servicebus
  ]
}

# Payments API - Azure Service Bus Data Sender
resource "azurerm_role_assignment" "payments_api_sb_sender" {
  principal_id         = azurerm_user_assigned_identity.payments_api.principal_id
  role_definition_name = "Azure Service Bus Data Sender"
  scope                = module.servicebus.namespace_id

  depends_on = [
    azurerm_user_assigned_identity.payments_api,
    module.servicebus
  ]
}

# Payments API - Azure Service Bus Data Receiver
resource "azurerm_role_assignment" "payments_api_sb_receiver" {
  principal_id         = azurerm_user_assigned_identity.payments_api.principal_id
  role_definition_name = "Azure Service Bus Data Receiver"
  scope                = module.servicebus.namespace_id

  depends_on = [
    azurerm_user_assigned_identity.payments_api,
    module.servicebus
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
  servicebus_namespace_id    = module.servicebus.namespace_id
  tags                       = local.common_tags

  depends_on = [
    module.resource_group,
    module.function_app_service_plan,
    module.logs,
    module.key_vault,
    module.servicebus
  ]
}

# External Secrets Operator installed via: aks-manager.ps1 install-eso

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
