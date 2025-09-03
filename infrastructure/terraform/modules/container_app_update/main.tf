# Container App Update Module
# This module updates existing Container Apps with Key Vault secrets
# after role assignments have been created

# Data source for existing Container App
data "azurerm_container_app" "existing" {
  name                = var.container_app_name
  resource_group_name = var.resource_group_name
}

# Update Container App with Key Vault secrets
resource "azurerm_container_app" "updated" {
  name                         = var.container_app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = data.azurerm_container_app.existing.container_app_environment_id
  revision_mode                = "Single"

  # Inherit all existing settings but update template
  identity {
    type = "SystemAssigned"
  }

  secret {
    name                = "db-host"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-host"
    identity            = "System"
  }

  secret {
    name                = "db-port"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-port"
    identity            = "System"
  }

  secret {
    name                = var.db_name
    key_vault_secret_id = "${var.key_vault_id}secrets/${var.db_name}"
    identity            = "System"
  }

  secret {
    name                = "db-admin-login"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-admin-login"
    identity            = "System"
  }

  secret {
    name                = "db-password"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-password"
    identity            = "System"
  }

  secret {
    name                = "db-name-maintenance"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-name-maintenance"
    identity            = "System"
  }

  secret {
    name                = "db-schema"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-schema"
    identity            = "System"
  }

  secret {
    name                = "db-connection-timeout"
    key_vault_secret_id = "${var.key_vault_id}secrets/db-connection-timeout"
    identity            = "System"
  }

  secret {
    name                = "cache-host"
    key_vault_secret_id = "${var.key_vault_id}secrets/cache-host"
    identity            = "System"
  }

  secret {
    name                = "cache-port"
    key_vault_secret_id = "${var.key_vault_id}secrets/cache-port"
    identity            = "System"
  }

  secret {
    name                = "cache-password"
    key_vault_secret_id = "${var.key_vault_id}secrets/cache-password"
    identity            = "System"
  }

  secret {
    name                = "cache-secure"
    key_vault_secret_id = "${var.key_vault_id}secrets/cache-secure"
    identity            = "System"
  }

  secret {
    name                = "servicebus-connection-string"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-connection-string"
    identity            = "System"
  }

  secret {
    name                = "servicebus-topic-name"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-topic-name"
    identity            = "System"
  }

  secret {
    name                = "servicebus-subscription-name"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-subscription-name"
    identity            = "System"
  }

  secret {
    name                = "servicebus-auto-provision"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-auto-provision"
    identity            = "System"
  }

  secret {
    name                = "servicebus-max-delivery-count"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-max-delivery-count"
    identity            = "System"
  }

  secret {
    name                = "servicebus-enable-dead-lettering"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-enable-dead-lettering"
    identity            = "System"
  }

  secret {
    name                = "servicebus-auto-purge-on-startup"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-auto-purge-on-startup"
    identity            = "System"
  }

  secret {
    name                = "servicebus-use-control-queues"
    key_vault_secret_id = "${var.key_vault_id}secrets/servicebus-use-control-queues"
    identity            = "System"
  }

  # Container configuration with Key Vault secret references
  template {
    min_replicas = data.azurerm_container_app.existing.template[0].min_replicas
    max_replicas = data.azurerm_container_app.existing.template[0].max_replicas

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
        name        = "CACHE_SECURE"
        secret_name = "cache-secure"
      }

      env {
        name        = "AZURE_SERVICEBUS_CONNECTIONSTRING"
        secret_name = "servicebus-connection-string"
      }

      env {
        name        = "AZURE_SERVICEBUS_TOPIC_NAME"
        secret_name = "servicebus-topic-name"
      }

      env {
        name        = "AZURE_SERVICEBUS_SUBSCRIPTION_NAME"
        secret_name = "servicebus-subscription-name"
      }

      env {
        name        = "AZURE_SERVICEBUS_AUTO_PROVISION"
        secret_name = "servicebus-auto-provision"
      }

      env {
        name        = "AZURE_SERVICEBUS_MAX_DELIVERY_COUNT"
        secret_name = "servicebus-max-delivery-count"
      }

      env {
        name        = "AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING"
        secret_name = "servicebus-enable-dead-lettering"
      }

      env {
        name        = "AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP"
        secret_name = "servicebus-auto-purge-on-startup"
      }

      env {
        name        = "AZURE_SERVICEBUS_USE_CONTROL_QUEUES"
        secret_name = "servicebus-use-control-queues"
      }
    }
  }

  ingress {
    external_enabled = data.azurerm_container_app.existing.ingress[0].external_enabled
    target_port      = data.azurerm_container_app.existing.ingress[0].target_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = data.azurerm_container_app.existing.tags

  # Ensure this runs after role assignments
  depends_on = [var.role_assignment_dependencies]

  timeouts {
    create = "10m"  # Reduced from 20m to 10m
    update = "10m"  # Reduced from 20m to 10m  
    delete = "10m"  # Reduced from 20m to 10m
  }

  # Lifecycle management to reduce recreation
  lifecycle {
    ignore_changes = [
      # Ignore changes that don't require recreation
      template[0].revision_suffix
    ]
  }
}
