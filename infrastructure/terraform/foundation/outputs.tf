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
# Service Bus
# =============================================================================

output "servicebus_info" {
  description = "Azure Service Bus details"
  value = {
    namespace     = module.servicebus.namespace_name
    namespace_id  = module.servicebus.namespace_id
    topic         = module.servicebus.topic_name
    subscription  = module.servicebus.subscription_name
  }
}

# =============================================================================
# Aggregated Resource Map (useful for pipelines)
# =============================================================================

output "all_resources" {
  description = "Aggregated resource names for quick reference"
  value = {
    resource_group     = module.resource_group.name
    acr_name           = module.acr.acr_name
    acr_login_server   = module.acr.acr_login_server
    postgres_server    = module.postgres.postgres_server_name
    postgres_fqdn      = module.postgres.postgres_server_fqdn
    redis_name         = module.redis.redis_name
    redis_host         = module.redis.redis_hostname
    log_analytics_name = module.logs.log_analytics_name
    servicebus_ns      = module.servicebus.namespace_name
    servicebus_topic   = module.servicebus.topic_name
    location           = module.resource_group.location
  }
}

# =============================================================================
# Connection & Debug Info
# =============================================================================

output "connection_info" {
  description = "Non-sensitive connection info for debugging or next stages"
  value = {
    postgres_host = module.postgres.postgres_server_fqdn
    postgres_port = module.postgres.postgres_port
    acr_server    = module.acr.acr_login_server
    redis_host    = module.redis.redis_hostname
    redis_port    = module.redis.redis_ssl_port
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
    total_resources      = 6 # resource_group + postgres + acr + redis + log_analytics + servicebus
    deployment_timestamp = timestamp()
  }
}
