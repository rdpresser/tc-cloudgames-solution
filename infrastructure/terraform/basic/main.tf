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

  kv_name = "tccgames${local.environment}kv${random_string.unique_suffix.result}"

  common_tags = {
    Environment = local.environment
    Project     = "TCC Games"
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
  name_prefix = "${local.project_name}-basic-${local.environment}-rg"
  location    = var.azure_resource_group_location
  tags        = local.common_tags
}

# =============================================================================
# Service Bus module
# =============================================================================
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
          filter_expression = "DomainAggregate = 'GameAggregate' and MessageType = 'GamePurchasePaymentApprovedFunctionEvent'"
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
# Deployment Timing - End Timestamp and Duration Calculation
# =============================================================================
locals {
  deployment_end_time = timestamp()

  # Calculate duration in seconds (approximation since both timestamps are taken at plan time)
  # Note: This gives an estimate since both timestamps are captured during planning phase
  # For more accurate measurement, use external timing in CI/CD pipeline
  deployment_duration_estimate = "Measured by CI/CD pipeline for accurate timing"
}
