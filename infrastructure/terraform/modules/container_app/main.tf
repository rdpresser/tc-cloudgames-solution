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
      image  = var.container_image
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

  # Key Vault secret references using System Managed Identity
  secret {
    name                = "db-host"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-host"
  }

  secret {
    name                = "db-port"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-port"
  }

  secret {
    name                = var.db_name
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/${var.db_name}"
  }

  secret {
    name                = "db-name-maintenance"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-name-maintenance"
  }

  secret {
    name                = "db-schema"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-schema"
  }

  secret {
    name                = "db-connection-timeout"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-connection-timeout"
  }

  secret {
    name                = "db-admin-login"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-admin-login"
  }

  secret {
    name                = "db-password"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/db-password"
  }

  secret {
    name                = "cache-host"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/cache-host"
  }

  secret {
    name                = "cache-port"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/cache-port"
  }

  secret {
    name                = "cache-password"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/cache-password"
  }

  secret {
    name                = "cache-secure"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/cache-secure"
  }

  secret {
    name                = "servicebus-connection-string"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-connection-string"
  }

  secret {
    name                = "servicebus-auto-provision"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-auto-provision"
  }

  secret {
    name                = "servicebus-max-delivery-count"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-max-delivery-count"
  }

  secret {
    name                = "servicebus-enable-dead-lettering"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-enable-dead-lettering"
  }

  secret {
    name                = "servicebus-auto-purge-on-startup"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-auto-purge-on-startup"
  }

  secret {
    name                = "servicebus-use-control-queues"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-use-control-queues"
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

  # ACR configuration using System Managed Identity
  registry {
    server   = var.container_registry_server
    identity = "System"
  }

  # Custom timeouts to prevent operation expired errors
  timeouts {
    create = "20m"  # Increased from 15m to 20m
    update = "15m"  # Increased from 10m to 15m
    delete = "10m"
  }
}

# =============================================================================
# Role Assignments for Container App (created AFTER Container App exists)
# =============================================================================

# Key Vault Secrets User Role Assignment
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

# ACR Pull Role Assignment
resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${split(".", var.container_registry_server)[0]}"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}