# ===================================================================================================
# Container App Resources
# Creates Container App with System Managed Identity and Key Vault secret references
# ===================================================================================================

# Container App with System Managed Identity
resource "azurerm_container_app" "main" {
  name                         = "${var.name_prefix}-${var.service_name}"
  location                     = var.location
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

      # Dynamic environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      # Key Vault secret references for infrastructure secrets
      env {
        name        = "DATABASE_CONNECTION_STRING"
        secret_name = "postgres-connection-string"
      }

      env {
        name        = "REDIS_CONNECTION_STRING" 
        secret_name = "redis-connection-string"
      }

      env {
        name        = "SERVICEBUS_CONNECTION_STRING"
        secret_name = "servicebus-connection-string"
      }

      env {
        name        = "ACR_LOGIN_SERVER"
        secret_name = "acr-login-server"
      }
    }
  }

  # Key Vault secret references using System Managed Identity
  secret {
    name  = "postgres-connection-string"
    value = "https://${var.key_vault_name}.vault.azure.net/secrets/postgres-connection-string"
    identity = "system"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/postgres-connection-string"
  }

  secret {
    name  = "redis-connection-string"
    value = "https://${var.key_vault_name}.vault.azure.net/secrets/redis-connection-string"
    identity = "system" 
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/redis-connection-string"
  }

  secret {
    name  = "servicebus-connection-string"
    value = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-connection-string"
    identity = "system"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/servicebus-connection-string"
  }

  secret {
    name  = "acr-login-server"
    value = "https://${var.key_vault_name}.vault.azure.net/secrets/acr-login-server"
    identity = "system"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/acr-login-server"
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
    identity = "system"
  }
}

# Data source to get Container App System Managed Identity principal ID
data "azurerm_container_app" "identity" {
  name                = azurerm_container_app.main.name
  resource_group_name = var.resource_group_name
  depends_on         = [azurerm_container_app.main]
}

# Role assignment: Grant Key Vault Secrets User role to Container App System MI
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_container_app.identity.identity[0].principal_id
}

# Role assignment: Grant ACR Pull role to Container App System MI for container image access
resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${split(".", var.container_registry_server)[0]}"
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_container_app.identity.identity[0].principal_id
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}
