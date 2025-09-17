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
# Aggregated Resource Map (useful for pipelines)
# =============================================================================

output "all_resources" {
  description = "Aggregated resource names for quick reference"
  value = {
    resource_group   = module.resource_group.name
    servicebus_ns    = module.servicebus.namespace_name
    servicebus_topic = module.servicebus.topic_name
    location         = module.resource_group.location
  }
}

# =============================================================================
# Connection & Debug Info
# =============================================================================

output "connection_info" {
  description = "Non-sensitive connection info for debugging or next stages"
  value = {
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
    total_resources      = 2 # rg + servicebus
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
