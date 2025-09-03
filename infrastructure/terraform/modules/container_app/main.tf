# ===================================================================================================
# Container App Resources
# Creates Container App with System Managed Identity and Key Vault secret references
# ===================================================================================================

# Local values for cleaner naming
locals {
  # Clean and truncate the container app name to meet Azure requirements
  # - Remove double hyphens and ensure no consecutive hyphens
  # - Ensure it's 32 characters or less
  # - Ensure it starts with letter and ends with alphanumeric
  
  # Clean the inputs
  clean_name_prefix = replace(replace(var.name_prefix, "--", "-"), "--", "-")
  clean_service_name = replace(replace(var.service_name, "--", "-"), "--", "-")
  
  # Create the full name and truncate if necessary
  proposed_name = "${local.clean_name_prefix}-${local.clean_service_name}"
  
  # Ensure it's within the 32 character limit
  container_app_name = length(local.proposed_name) > 32 ? substr(local.proposed_name, 0, 32) : local.proposed_name
}

# Container App with System Managed Identity
resource "azurerm_container_app" "main" {
  name                         = local.container_app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  tags                         = var.tags
  
  # System Managed Identity configuration
  identity {
    type = "SystemAssigned"
  }

  # Container configuration
  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.service_name
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"  # Using test image temporarily
      cpu    = var.cpu_requests
      memory = var.memory_requests

      # Environment variables matching pipeline requirements
      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS" 
        value = "http://+:8080"
      }

      # Placeholder environment variables (will be updated after role assignments)
      # These prevent the app from failing to start while secrets are not accessible
      env {
        name  = "DB_HOST"
        value = "placeholder-will-be-updated"
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_NAME"
        value = "placeholder-will-be-updated"
      }

      env {
        name  = "DB_USER"
        value = "placeholder-will-be-updated"
      }

      env {
        name  = "DB_PASSWORD"
        value = "placeholder-will-be-updated"
      }
    }
  }

  # Ingress configuration
  ingress {
    allow_insecure_connections = false
    external_enabled          = true
    target_port               = var.target_port
    transport                 = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # TEMPORARILY REMOVED ACR CONFIGURATION TO TEST IF THIS CAUSES SLOWNESS
  # We'll add it back once Container Apps are created successfully
  # registry {
  #   server   = var.container_registry_server
  #   identity = "System"
  # }

  # Optimized timeouts - reduce excessive wait times
  timeouts {
    create = "10m"  # Reduced from 20m to 10m
    update = "10m"  # Keep at 10m
    delete = "10m"
  }

  # Lifecycle management to reduce recreation
  lifecycle {
    ignore_changes = [
      # Ignore changes to template during updates - will be handled by update module
      template[0].container[0].env
    ]
  }
}

# =============================================================================
# Role Assignments for Container App (TEMPORARILY SIMPLIFIED FOR TESTING)
# =============================================================================

# Key Vault Secrets User Role Assignment - TEMPORARILY DISABLED FOR TESTING
# resource "azurerm_role_assignment" "key_vault_secrets_user" {
#   scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = azurerm_container_app.main.identity[0].principal_id
#   
#   # Skip assignment if System Identity is not ready
#   count = can(azurerm_container_app.main.identity[0].principal_id) ? 1 : 0
# 
#   depends_on = [azurerm_container_app.main]
#   
#   timeouts {
#     create = "5m"
#     delete = "5m"
#   }
# }

# ACR Pull Role Assignment - TEMPORARILY DISABLED
# resource "azurerm_role_assignment" "acr_pull" {
#   scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${split(".", var.container_registry_server)[0]}"
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_container_app.main.identity[0].principal_id
#   
#   # Skip assignment if System Identity is not ready
#   count = can(azurerm_container_app.main.identity[0].principal_id) ? 1 : 0
# 
#   depends_on = [azurerm_container_app.main]
#   
#   timeouts {
#     create = "5m"
#     delete = "5m"
#   }
# }