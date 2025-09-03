# =============================================================================
# Core Resource Group
# =============================================================================

output "foundation_rg_name" {
  description = "The name of the Resource Group created in foundation"
  value       = module.resource_group.name
}

output "foundation_rg_id" {
  description = "The ID of the Resource Group created in foundation"
  value       = module.resource_group.id
}

output "foundation_rg_location" {
  description = "The location of the Resource Group"
  value       = module.resource_group.location
}

output "azure_portal_rg_url" {
  description = "Direct link to the Resource Group in Azure Portal"
  value       = "https://portal.azure.com/#@/resource${module.resource_group.id}/overview"
}

# =============================================================================
# PostgreSQL Flexible Server
# =============================================================================

output "postgres_info" {
  description = "PostgreSQL connection and metadata"
  value = {
    name    = module.postgres.postgres_server_name
    fqdn    = module.postgres.postgres_server_fqdn
    id      = module.postgres.postgres_server_id
    version = module.postgres.postgres_server_version
    port    = module.postgres.postgres_port
    dbs     = module.postgres.postgres_databases
  }
}

# =============================================================================
# Azure Container Registry (ACR)
# =============================================================================

output "acr_info" {
  description = "Azure Container Registry details"
  value = {
    name         = module.acr.acr_name
    login_server = module.acr.acr_login_server
    id           = module.acr.acr_id
    sku          = module.acr.acr_sku
    admin        = module.acr.acr_admin_enabled
  }
}

# =============================================================================
# Redis Cache
# =============================================================================

output "redis_info" {
  description = "Redis Cache details"
  value = {
    name     = module.redis.redis_name
    id       = module.redis.redis_id
    host     = module.redis.redis_hostname
    ssl_port = module.redis.redis_ssl_port
    sku      = module.redis.redis_sku
  }
}

# =============================================================================
# Log Analytics Workspace
# =============================================================================

output "log_analytics_info" {
  description = "Log Analytics Workspace details"
  value = {
    name = module.logs.log_analytics_name
    id   = module.logs.log_analytics_workspace_id
  }
}

# =============================================================================
# Container App Environment
# =============================================================================

output "container_app_environment_info" {
  description = "Container App Environment details"
  value = {
    name = module.container_app_environment.container_app_environment_name
    id   = module.container_app_environment.container_app_environment_id
  }
}

# =============================================================================
# Key Vault
# =============================================================================

output "key_vault_info" {
  description = "Key Vault details"
  value = {
    name = module.key_vault.key_vault_name
    id   = module.key_vault.key_vault_id
    uri  = module.key_vault.key_vault_uri
  }
}

# =============================================================================
# Service Bus
# =============================================================================

output "servicebus_info" {
  description = "Azure Service Bus details"
  value = {
    namespace    = module.servicebus.namespace_name
    namespace_id = module.servicebus.namespace_id
    topic        = module.servicebus.topic_name
    subscription = module.servicebus.subscription_name
  }
}

# =============================================================================
# Users API Container App
# =============================================================================

output "users_api_container_app_info" {
  description = "Users API Container App details"
  value = {
    name               = module.users_api_container_app.container_app_name
    id                 = module.users_api_container_app.container_app_id
    fqdn               = module.users_api_container_app.container_app_fqdn
    system_identity_id = module.users_api_container_app.system_assigned_identity_principal_id
  }
}

# =============================================================================
# Games API Container App
# =============================================================================

output "games_api_container_app_info" {
  description = "Games API Container App details"
  value = {
    name               = module.games_api_container_app.container_app_name
    id                 = module.games_api_container_app.container_app_id
    fqdn               = module.games_api_container_app.container_app_fqdn
    system_identity_id = module.games_api_container_app.system_assigned_identity_principal_id
  }
}

# =============================================================================
# Payments API Container App
# =============================================================================

output "payments_api_container_app_info" {
  description = "Payments API Container App details"
  value = {
    name               = module.payments_api_container_app.container_app_name
    id                 = module.payments_api_container_app.container_app_id
    fqdn               = module.payments_api_container_app.container_app_fqdn
    system_identity_id = module.payments_api_container_app.system_assigned_identity_principal_id
  }
}

# =============================================================================
# Container Apps Role Assignments (for dependency management)
# =============================================================================

output "container_apps_role_assignments" {
  description = "Role assignments for all Container Apps (useful for dependencies)"
  value = {
    users_api = {
      key_vault_secrets_user = module.users_api_container_app.role_assignment_key_vault_secrets_user_id
      acr_pull               = module.users_api_container_app.role_assignment_acr_pull_id
    }
    games_api = {
      key_vault_secrets_user = module.games_api_container_app.role_assignment_key_vault_secrets_user_id
      acr_pull               = module.games_api_container_app.role_assignment_acr_pull_id
    }
    payments_api = {
      key_vault_secrets_user = module.payments_api_container_app.role_assignment_key_vault_secrets_user_id
      acr_pull               = module.payments_api_container_app.role_assignment_acr_pull_id
    }
  }
}

# =============================================================================
# Aggregated Resource Map (useful for pipelines)
# =============================================================================

output "all_resources" {
  description = "Aggregated resource names for quick reference"
  value = {
    resource_group             = module.resource_group.name
    acr_name                   = module.acr.acr_name
    acr_login_server           = module.acr.acr_login_server
    postgres_server            = module.postgres.postgres_server_name
    postgres_fqdn              = module.postgres.postgres_server_fqdn
    redis_name                 = module.redis.redis_name
    redis_host                 = module.redis.redis_hostname
    log_analytics_name         = module.logs.log_analytics_name
    servicebus_ns              = module.servicebus.namespace_name
    servicebus_topic           = module.servicebus.topic_name
    users_api_container_app    = module.users_api_container_app.container_app_name
    games_api_container_app    = module.games_api_container_app.container_app_name
    payments_api_container_app = module.payments_api_container_app.container_app_name
    container_app_environment  = module.container_app_environment.container_app_environment_name
    key_vault                  = module.key_vault.key_vault_name
    location                   = module.resource_group.location
  }
}

# =============================================================================
# Connection & Debug Info
# =============================================================================

output "connection_info" {
  description = "Non-sensitive connection info for debugging or next stages"
  value = {
    postgres_host        = module.postgres.postgres_server_fqdn
    postgres_port        = module.postgres.postgres_port
    acr_server           = module.acr.acr_login_server
    redis_host           = module.redis.redis_hostname
    redis_port           = module.redis.redis_ssl_port
    servicebus_namespace = module.servicebus.namespace_name
    servicebus_topic     = module.servicebus.topic_name
  }
}

# =============================================================================
# Deployment Summary
# =============================================================================

output "deployment_summary" {
  description = "High-level summary of the foundation deployment"
  value = {
    environment          = local.environment
    location             = module.resource_group.location
    resource_group       = module.resource_group.name
    total_resources      = 11 # rg + postgres + acr + redis + log_analytics + servicebus + container_app_env + key_vault + users_api + games_api + payments_api
    deployment_timestamp = timestamp()
  }
}

# =============================================================================
# Deployment Performance Metrics
# =============================================================================

output "deployment_timing" {
  description = "Infrastructure deployment timing information"
  value = {
    terraform_start_time = local.deployment_start_time
    terraform_end_time   = local.deployment_end_time
    note                 = "Terraform timestamps are estimates. Use CI/CD pipeline GITHUB_STEP_SUMMARY for accurate timing."
    measurement_source   = "CI/CD Pipeline"
  }
}

output "deployment_performance_summary" {
  description = "Deployment performance metadata"
  value = {
    # Basic deployment info
    environment         = var.environment
    terraform_workspace = terraform.workspace
    resource_count      = 11 # rg + postgres + acr + redis + log_analytics + servicebus + container_app_env + key_vault + users_api + games_api + payments_api
    deployment_method   = "Pure Terraform via Terraform Cloud"

    # Deployment metadata
    deployment_date = formatdate("YYYY-MM-DD", local.deployment_end_time)
    deployment_time = formatdate("hh:mm:ss", local.deployment_end_time)

    # Performance targets
    performance_targets = {
      excellent  = "< 5 minutes"
      good       = "5-10 minutes"
      acceptable = "10-15 minutes"
      slow       = "> 15 minutes"
    }

    # Note about accurate timing
    timing_note = "Actual deployment duration measured by GitHub Actions pipeline with start/end timestamps"
  }
}
