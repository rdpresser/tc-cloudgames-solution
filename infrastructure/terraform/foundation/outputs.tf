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
    namespace          = module.servicebus.namespace_name
    namespace_id       = module.servicebus.namespace_id
    topic_names        = module.servicebus.topic_names
    topic_ids          = module.servicebus.topic_ids
    subscription_names = module.servicebus.subscription_names
    subscription_ids   = module.servicebus.subscription_ids
  }
}

# =============================================================================
# Azure Function App
# =============================================================================

output "function_app_info" {
  description = "Azure Function App details"
  value = {
    name                    = module.function_app.function_app_name
    id                      = module.function_app.function_app_id
    default_hostname        = module.function_app.function_app_default_hostname
    principal_id            = module.function_app.function_app_principal_id
    storage_account         = module.function_app.storage_account_name
    application_insights_id = module.function_app.application_insights_id
  }
}

output "function_app_service_plan_info" {
  description = "Azure Function App Service Plan details"
  value = {
    name = module.function_app_service_plan.app_service_plan_name
    id   = module.function_app_service_plan.app_service_plan_id
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
    servicebus_topics  = module.servicebus.topic_names
    function_app       = module.function_app.function_app_name
    key_vault          = module.key_vault.key_vault_name
    aks_cluster        = module.aks.cluster_name
    vnet_name          = module.vnet.vnet_name
    location           = module.resource_group.location
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
    servicebus_topics    = module.servicebus.topic_names
    aks_cluster          = module.aks.cluster_name
    aks_fqdn             = module.aks.cluster_fqdn
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
    total_resources      = 13 # rg + postgres + acr + redis + log_analytics + servicebus + function_app + key_vault + vnet + aks + apim + 2 role_assignments
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
    resource_count      = 13 # rg + postgres + acr + redis + log_analytics + servicebus + function_app + key_vault + vnet + aks + apim + 2 role_assignments
    deployment_method   = "Pure Terraform via Terraform Cloud"

    # Deployment metadata
    deployment_date = formatdate("YYYY-MM-DD", local.deployment_end_time)
    deployment_time = formatdate("hh:mm:ss", local.deployment_end_time)

    # Performance targets
    performance_targets = {
      excellent  = "< 8 minutes"
      good       = "8-12 minutes"
      acceptable = "12-18 minutes"
      slow       = "> 18 minutes"
    }

    # Note about accurate timing
    timing_note = "Actual deployment duration measured by GitHub Actions pipeline with start/end timestamps. AKS creation adds ~5-10 minutes to total time."
  }
}

# =============================================================================
# API Management
# =============================================================================

output "apim_info" {
  description = "Azure API Management details"
  value = {
    name           = module.apim.apim_name
    id             = module.apim.apim_id
    location       = module.apim.apim_location
    gateway_url    = module.apim.apim_gateway_url
    portal_url     = module.apim.apim_portal_url
    management_url = module.apim.apim_management_api_url
    resource_group = module.apim.resource_group_name
  }
}

# APIM APIs outputs commented out since APIs are managed manually
# output "apim_apis_info" {
#   description = "API Management APIs details"
#   value = {
#     for key, api in module.apim_api : key => {
#       name         = api.api_name
#       id           = api.api_id
#       display_name = api.api_display_name
#       path         = api.api_path
#       revision     = api.api_revision
#     }
#   }
# }

# =============================================================================
# Virtual Network
# =============================================================================

output "vnet_info" {
  description = "Virtual Network details"
  value = {
    id            = module.vnet.vnet_id
    name          = module.vnet.vnet_name
    address_space = module.vnet.vnet_address_space
    aks_subnet_id = module.vnet.aks_subnet_id
  }
}

# =============================================================================
# AKS Cluster
# =============================================================================

output "aks_info" {
  description = "Azure Kubernetes Service (AKS) cluster details"
  value = {
    id                  = module.aks.cluster_id
    name                = module.aks.cluster_name
    fqdn                = module.aks.cluster_fqdn
    kubernetes_version  = module.aks.kubernetes_version
    node_resource_group = module.aks.node_resource_group
    oidc_issuer_url     = module.aks.oidc_issuer_url
    kubelet_identity = {
      client_id = module.aks.kubelet_identity.client_id
      object_id = module.aks.kubelet_identity.object_id
    }
  }
}

output "aks_kube_config_raw" {
  description = "Raw kubeconfig for kubectl (use: az aks get-credentials instead)"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "aks_get_credentials_command" {
  description = "Command to configure kubectl with AKS credentials"
  value       = "az aks get-credentials --resource-group ${module.resource_group.name} --name ${module.aks.cluster_name}"
}

# =============================================================================
# ArgoCD
# =============================================================================
# REMOVED: ArgoCD is now installed manually via install-argocd-aks.ps1 script.
# These outputs are no longer available from Terraform.
# =============================================================================
# output "argocd_info" {
#   description = "ArgoCD deployment details"
#   value = {
#     namespace              = module.argocd.argocd_namespace
#     server_url             = module.argocd.argocd_server_url
#     server_ip              = module.argocd.argocd_server_ip
#     admin_username         = module.argocd.admin_username
#     helm_release_name      = module.argocd.helm_release_name
#     helm_release_version   = module.argocd.helm_release_version
#     port_forward_command   = module.argocd.kubectl_port_forward_command
#     cli_login_command_hint = module.argocd.argocd_cli_login_command
#   }
# }
#
# output "argocd_server_url" {
#   description = "ArgoCD server external URL (LoadBalancer IP)"
#   value       = module.argocd.argocd_server_url
# }
#
# output "argocd_admin_username" {
#   description = "ArgoCD admin username"
#   value       = "admin"
# }

# =============================================================================
# Grafana Agent Outputs
# =============================================================================

output "grafana_agent_enabled" {
  description = "Whether Grafana Agent is enabled"
  value       = var.enable_grafana_agent
}

output "grafana_agent_info" {
  description = "Grafana Agent deployment details"
  value = var.enable_grafana_agent ? {
    namespace            = module.grafana_agent[0].namespace
    helm_release_name    = module.grafana_agent[0].helm_release_name
    helm_release_version = module.grafana_agent[0].helm_release_version
    helm_release_status  = module.grafana_agent[0].helm_release_status
    prometheus_url       = module.grafana_agent[0].grafana_cloud_prometheus_url
    loki_url             = module.grafana_agent[0].grafana_cloud_loki_url
    kubectl_command      = "kubectl get pods -n ${module.grafana_agent[0].namespace}"
  } : null
}

# =============================================================================
# External Secrets Operator
# =============================================================================

output "external_secrets_info" {
  description = "External Secrets Operator deployment details"
  value = {
    identity_name      = module.external_secrets.eso_identity_name
    identity_client_id = module.external_secrets.eso_identity_client_id
    namespace          = module.external_secrets.eso_namespace
    service_account    = module.external_secrets.eso_service_account_name
    kubectl_command    = "kubectl get pods -n ${module.external_secrets.eso_namespace}"
  }
}

output "eso_workload_identity_client_id" {
  description = "Client ID for External Secrets Workload Identity (use in ClusterSecretStore)"
  value       = module.external_secrets.eso_identity_client_id
}

# =============================================================================
# NGINX Ingress Controller
# =============================================================================

output "nginx_ingress_info" {
  description = "NGINX Ingress Controller deployment details"
  value = {
    namespace       = module.nginx_ingress.nginx_namespace
    release_name    = module.nginx_ingress.nginx_release_name
    chart_version   = module.nginx_ingress.nginx_chart_version
    kubectl_command = "kubectl get svc -n ${module.nginx_ingress.nginx_namespace}"
  }
}

