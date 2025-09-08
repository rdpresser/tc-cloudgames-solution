# =============================================================================
# Container App Single Shot Module
# =============================================================================
# This module creates a Container App with System Managed Identity and RBAC 
# permissions, but does NOT configure environment variables.
#
# Environment variables are configured via GitHub Actions pipeline using 
# azure/container-apps-deploy-action@v2 with secretref pattern pointing to 
# Key Vault secrets.
#
# This approach:
# - Keeps infrastructure and deployment configuration separate
# - Allows environment variables to be updated without Terraform
# - Uses the same secret refs across all services
# - Simplifies the Terraform module
# =============================================================================

locals {
  clean_prefix      = replace(replace(var.name_prefix, "--", "-"), "--", "-")
  clean_service     = replace(replace(var.service_name, "--", "-"), "--", "-")
  proposed_name     = "${local.clean_prefix}-${local.clean_service}"
  containerapp_name = length(local.proposed_name) > 32 ? substr(local.proposed_name, 0, 32) : local.proposed_name
}

# =============================================================================
# Container App with System Assigned Identity and Key Vault Secret Bindings
# =============================================================================
# This resource deploys a Container App configured with a System Assigned Identity.
# All secrets are bound directly from Azure Key Vault using the system identity.
# No environment variables are defined here - they will be referenced in the pipeline
# via `secretref` to keep application configuration decoupled from infrastructure.
# =============================================================================

resource "azurerm_container_app" "main" {
  name                         = local.containerapp_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  tags                         = var.tags

  # -------------------------------------------------------------------
  # Enable System Assigned Identity (used for ACR pull + Key Vault access)
  # -------------------------------------------------------------------
  identity {
    type = "SystemAssigned"
  }

  # -------------------------------------------------------------------
  # Application Template (basic container config, no env vars here)
  # -------------------------------------------------------------------
  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.service_name
      image  = var.container_image_placeholder
      cpu    = var.cpu_requests
      memory = var.memory_requests
    }
  }

  # -------------------------------------------------------------------
  # Public ingress (HTTP)
  # -------------------------------------------------------------------
  ingress {
    external_enabled = true
    target_port      = var.target_port
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # -------------------------------------------------------------------
  # Key Vault Secret References (system identity authentication)
  # These secrets are injected into the Container App and later mapped
  # as environment variables using `secretref` in the CI/CD pipeline.
  # -------------------------------------------------------------------

  # Database secrets
  secret {
    name                = "db-host"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-host"
    identity            = "System"
  }

  secret {
    name                = "db-port"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-port"
    identity            = "System"
  }

  secret {
    name                = var.db_name_secret_ref
    key_vault_secret_id = "${var.key_vault_uri}/secrets/${var.db_name_secret_ref}"
    identity            = "System"
  }

  secret {
    name                = "db-admin-login"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-admin-login"
    identity            = "System"
  }

  secret {
    name                = "db-password"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-password"
    identity            = "System"
  }

  secret {
    name                = "db-name-maintenance"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-name-maintenance"
    identity            = "System"
  }

  secret {
    name                = "db-schema"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-schema"
    identity            = "System"
  }

  secret {
    name                = "db-connection-timeout"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-connection-timeout"
    identity            = "System"
  }

  # Cache secrets
  secret {
    name                = "cache-host"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-host"
    identity            = "System"
  }

  secret {
    name                = "cache-port"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-port"
    identity            = "System"
  }

  secret {
    name                = "cache-password"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-password"
    identity            = "System"
  }

  secret {
    name                = "cache-secure"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-secure"
    identity            = "System"
  }

  # Service Bus secrets
  secret {
    name                = "servicebus-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-connection-string"
    identity            = "System"
  }

  secret {
    name                = "servicebus-auto-provision"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-auto-provision"
    identity            = "System"
  }

  secret {
    name                = "servicebus-max-delivery-count"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-max-delivery-count"
    identity            = "System"
  }

  secret {
    name                = "servicebus-enable-dead-lettering"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-enable-dead-lettering"
    identity            = "System"
  }

  secret {
    name                = "servicebus-auto-purge-on-startup"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-auto-purge-on-startup"
    identity            = "System"
  }

  secret {
    name                = "servicebus-use-control-queues"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-use-control-queues"
    identity            = "System"
  }

  timeouts {
    create = var.timeouts_create
    update = var.timeouts_update
    delete = var.timeouts_delete
  }
}

# -------------------------------------------------------------------
# 2) RBAC: Container App MI pode pull do ACR
# -------------------------------------------------------------------
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

# -------------------------------------------------------------------
# 3) RBAC: Container App MI pode ler secrets do Key Vault
# -------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

# -------------------------------------------------------------------
# 4) Espera de propagação RBAC - Ensures RBAC is propagated
# -------------------------------------------------------------------
resource "time_sleep" "wait_for_rbac" {
  create_duration = "${var.rbac_propagation_wait_seconds}s"
  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.kv_secrets_user
  ]
}
