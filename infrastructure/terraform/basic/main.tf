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
module "servicebus" {
  source              = "../modules/service_bus"
  name_prefix         = local.full_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags

  # ⚠️  Resources serão criados via código C# (Wolverine/MassTransit)
  # Deixando tudo opcional para que a aplicação tenha controle total
  topics                  = []
  topic_subscriptions     = {}
  create_sql_filter_rules = false

  # 🔑 RBAC: Azure Service Bus Data Owner 
  # Permite que as APIs com Managed Identity criem filas, tópicos, subscriptions e regras SQL
  # Necessário para Wolverine criar automaticamente todos os recursos (wolverine.response.*, topics, filters, etc.)
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
