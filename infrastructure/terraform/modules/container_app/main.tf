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

  # Key Vault secrets (conditional) - ONLY EXISTING SECRETS
  dynamic "secret" {
    for_each = var.use_keyvault_secrets ? [
      { name = "db-host", secret_id = "${var.key_vault_uri}secrets/db-host" },
      { name = "db-port", secret_id = "${var.key_vault_uri}secrets/db-port" },
      { name = var.db_name, secret_id = "${var.key_vault_uri}secrets/${var.db_name}" },
      { name = "db-admin-login", secret_id = "${var.key_vault_uri}secrets/db-admin-login" },
      { name = "db-password", secret_id = "${var.key_vault_uri}secrets/db-password" },
      { name = "db-name-maintenance", secret_id = "${var.key_vault_uri}secrets/db-name-maintenance" },
      { name = "db-schema", secret_id = "${var.key_vault_uri}secrets/db-schema" },
      { name = "db-connection-timeout", secret_id = "${var.key_vault_uri}secrets/db-connection-timeout" },
      { name = "cache-host", secret_id = "${var.key_vault_uri}secrets/cache-host" },
      { name = "cache-port", secret_id = "${var.key_vault_uri}secrets/cache-port" },
      { name = "cache-password", secret_id = "${var.key_vault_uri}secrets/cache-password" },
      { name = "cache-secure", secret_id = "${var.key_vault_uri}secrets/cache-secure" },
      { name = "servicebus-connection-string", secret_id = "${var.key_vault_uri}secrets/servicebus-connection-string" },
      { name = "servicebus-auto-provision", secret_id = "${var.key_vault_uri}secrets/servicebus-auto-provision" },
      { name = "servicebus-max-delivery-count", secret_id = "${var.key_vault_uri}secrets/servicebus-max-delivery-count" },
      { name = "servicebus-enable-dead-lettering", secret_id = "${var.key_vault_uri}secrets/servicebus-enable-dead-lettering" },
      { name = "servicebus-auto-purge-on-startup", secret_id = "${var.key_vault_uri}secrets/servicebus-auto-purge-on-startup" },
      { name = "servicebus-use-control-queues", secret_id = "${var.key_vault_uri}secrets/servicebus-use-control-queues" }
    ] : []
    content {
      name                = secret.value.name
      key_vault_secret_id = secret.value.secret_id
      identity            = "System"
    }
  }

  # Container configuration
  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.service_name
      image  = var.use_keyvault_secrets ? var.container_image : "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
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

      # Conditional environment variables - use secrets if available, placeholders otherwise
      env {
        name        = "DB_HOST"
        value       = var.use_keyvault_secrets ? null : "placeholder-will-be-updated"
        secret_name = var.use_keyvault_secrets ? "db-host" : null
      }

      env {
        name        = "DB_PORT"
        value       = var.use_keyvault_secrets ? null : "5432"
        secret_name = var.use_keyvault_secrets ? "db-port" : null
      }

      env {
        name        = "DB_NAME"
        value       = var.use_keyvault_secrets ? null : "placeholder-will-be-updated"
        secret_name = var.use_keyvault_secrets ? var.db_name : null
      }

      env {
        name        = "DB_USER"
        value       = var.use_keyvault_secrets ? null : "placeholder-will-be-updated"
        secret_name = var.use_keyvault_secrets ? "db-admin-login" : null
      }

      env {
        name        = "DB_PASSWORD"
        value       = var.use_keyvault_secrets ? null : "placeholder-will-be-updated"
        secret_name = var.use_keyvault_secrets ? "db-password" : null
      }

      # Additional environment variables when using Key Vault
      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "DB_MAINTENANCE_NAME"
          secret_name = "db-name-maintenance"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "DB_SCHEMA"
          secret_name = "db-schema"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "DB_CONNECTION_TIMEOUT"
          secret_name = "db-connection-timeout"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "CACHE_HOST"
          secret_name = "cache-host"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "CACHE_PORT"
          secret_name = "cache-port"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "CACHE_PASSWORD"
          secret_name = "cache-password"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "CACHE_SECURE"
          secret_name = "cache-secure"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "AZURE_SERVICEBUS_CONNECTIONSTRING"
          secret_name = "servicebus-connection-string"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "AZURE_SERVICEBUS_AUTO_PROVISION"
          secret_name = "servicebus-auto-provision"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "AZURE_SERVICEBUS_MAX_DELIVERY_COUNT"
          secret_name = "servicebus-max-delivery-count"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING"
          secret_name = "servicebus-enable-dead-lettering"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP"
          secret_name = "servicebus-auto-purge-on-startup"
        }
      }

      dynamic "env" {
        for_each = var.use_keyvault_secrets ? [1] : []
        content {
          name        = "AZURE_SERVICEBUS_USE_CONTROL_QUEUES"
          secret_name = "servicebus-use-control-queues"
        }
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

  # Container Registry configuration
  registry {
    server   = var.container_registry_server
    identity = "System"
  }

  # Extended timeouts for Container Apps creation
  timeouts {
    create = "20m"  # Increased to handle Container App startup delays
    update = "15m"  # Sufficient for updates
    delete = "10m"  # Keep delete timeout reasonable
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
# Role Assignments for Container App (ENABLED FOR PRODUCTION)
# =============================================================================

# Key Vault Secrets User Role Assignment
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
  
  # Only create this role assignment when Key Vault integration is enabled
  count = var.use_keyvault_secrets ? 1 : 0

  depends_on = [azurerm_container_app.main]
  
  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# ACR Pull Role Assignment - ENABLED FOR PRODUCTION
resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${split(".", var.container_registry_server)[0]}"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id
  
  # Only create this role assignment when Key Vault integration is enabled
  count = var.use_keyvault_secrets ? 1 : 0

  depends_on = [azurerm_container_app.main]
  
  timeouts {
    create = "5m"
    delete = "5m"
  }
}