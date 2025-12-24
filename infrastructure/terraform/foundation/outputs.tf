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
# Workload Identity - User-Assigned Managed Identities
# =============================================================================

output "workload_identity_user_api" {
  description = "User API Workload Identity details"
  value = {
    client_id    = azurerm_user_assigned_identity.user_api.client_id
    principal_id = azurerm_user_assigned_identity.user_api.principal_id
    id           = azurerm_user_assigned_identity.user_api.id
    name         = azurerm_user_assigned_identity.user_api.name
  }
}

output "workload_identity_games_api" {
  description = "Games API Workload Identity details"
  value = {
    client_id    = azurerm_user_assigned_identity.games_api.client_id
    principal_id = azurerm_user_assigned_identity.games_api.principal_id
    id           = azurerm_user_assigned_identity.games_api.id
    name         = azurerm_user_assigned_identity.games_api.name
  }
}

output "workload_identity_payments_api" {
  description = "Payments API Workload Identity details"
  value = {
    client_id    = azurerm_user_assigned_identity.payments_api.client_id
    principal_id = azurerm_user_assigned_identity.payments_api.principal_id
    id           = azurerm_user_assigned_identity.payments_api.id
    name         = azurerm_user_assigned_identity.payments_api.name
  }
}

# Simplified client_id outputs for easy reference
output "user_api_client_id" {
  description = "Client ID for user-api Workload Identity (use in Kubernetes ServiceAccount annotation)"
  value       = azurerm_user_assigned_identity.user_api.client_id
}

output "games_api_client_id" {
  description = "Client ID for games-api Workload Identity (use in Kubernetes ServiceAccount annotation)"
  value       = azurerm_user_assigned_identity.games_api.client_id
}

output "payments_api_client_id" {
  description = "Client ID for payments-api Workload Identity (use in Kubernetes ServiceAccount annotation)"
  value       = azurerm_user_assigned_identity.payments_api.client_id
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
    total_resources      = 12 # rg + postgres + acr + redis + log_analytics + servicebus + function_app + function_app_service_plan + key_vault + vnet + aks + role_assignment
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
    resource_count      = 12 # rg + postgres + acr + redis + log_analytics + servicebus + function_app + function_app_service_plan + key_vault + vnet + aks + role_assignment
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

# ArgoCD installed via: aks-manager.ps1 install-argocd

# Grafana Agent installed via: aks-manager.ps1 install-grafana-agent

# External Secrets Operator installed via: aks-manager.ps1 install-eso

# NGINX Ingress Controller installed via: aks-manager.ps1 install-nginx


# =============================================================================
# NGINX Ingress Outputs
# =============================================================================
# NGINX Ingress instalado manualmente - IP obtido via:
# kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# output "nginx_ingress_ip" {
#   description = "Static IP address of NGINX Ingress Load Balancer"
#   value       = module.nginx_ingress.load_balancer_ip
# }

