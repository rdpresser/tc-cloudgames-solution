# ===================================================================================================
# Container App Resources
# Creates Container App with System Managed Identity and Key Vault secret references
# ===================================================================================================

# Container App with System Managed Identity
resource "azurerm_container_app" "main" {
  name                         = "${var.name_prefix}-${var.service_name}"
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

      # Key Vault secret references for infrastructure secrets
      env {
        name        = "DB_HOST"
        secret_name = "db-host"
      }

      env {
        name        = "DB_PORT"
        secret_name = "db-port"
      }

      env {
        name        = "DB_NAME"
        secret_name = var.db_name
      }

      env {
        name        = "DB_USER"
        secret_name = "db-admin-login"
      }

      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      env {
        name = "DB_MAINTENANCE_NAME"
        secret_name = "db-name-maintenance"
      }

      env {
        name        = "DB_SCHEMA"
        secret_name = "db-schema"
      }

      env {
        name        = "DB_CONNECTION_TIMEOUT"
        secret_name = "db-connection-timeout"
      }
      env {
        name        = "CACHE_HOST"
        secret_name = "cache-host"
      }

      env {
        name        = "CACHE_PORT"
        secret_name = "cache-port"
      }

      env {
        name        = "CACHE_PASSWORD"
        secret_name = "cache-password"
      }

      env {
        name        = "AZURE_SERVICEBUS_CONNECTIONSTRING"
        secret_name = "servicebus-connection-string"
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
    name                = "servicebus-connection-string"
    identity            = "System"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-connection-string"
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
}

# Role assignment: Grant Key Vault Secrets User role to Container App System MI
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}

# Role assignment: Grant ACR Pull role to Container App System MI for container image access
resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${split(".", var.container_registry_server)[0]}"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}