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

  acr_name = split(".", var.container_registry_server)[0]
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
    identity            = "system"
  }

  secret {
    name                = "db-port"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-port"
    identity            = "system"
  }

  secret {
    name                = var.db_name_secret_ref
    key_vault_secret_id = "${var.key_vault_uri}/secrets/${var.db_name_secret_ref}"
    identity            = "system"
  }

  secret {
    name                = "db-admin-login"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-admin-login"
    identity            = "system"
  }

  secret {
    name                = "db-password"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-password"
    identity            = "system"
  }

  secret {
    name                = "db-name-maintenance"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-name-maintenance"
    identity            = "system"
  }

  secret {
    name                = "db-schema"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-schema"
    identity            = "system"
  }

  secret {
    name                = "db-connection-timeout"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/db-connection-timeout"
    identity            = "system"
  }

  # Cache secrets
  secret {
    name                = "cache-host"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-host"
    identity            = "system"
  }

  secret {
    name                = "cache-port"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-port"
    identity            = "system"
  }

  secret {
    name                = "cache-password"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-password"
    identity            = "system"
  }

  secret {
    name                = "cache-secure"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/cache-secure"
    identity            = "system"
  }

  # Service Bus secrets
  secret {
    name                = "servicebus-connection-string"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-connection-string"
    identity            = "system"
  }

  secret {
    name                = "servicebus-auto-provision"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-auto-provision"
    identity            = "system"
  }

  secret {
    name                = "servicebus-max-delivery-count"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-max-delivery-count"
    identity            = "system"
  }

  secret {
    name                = "servicebus-enable-dead-lettering"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-enable-dead-lettering"
    identity            = "system"
  }

  secret {
    name                = "servicebus-auto-purge-on-startup"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-auto-purge-on-startup"
    identity            = "system"
  }

  secret {
    name                = "servicebus-use-control-queues"
    key_vault_secret_id = "${var.key_vault_uri}/secrets/servicebus-use-control-queues"
    identity            = "system"
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
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${local.acr_name}"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

# -------------------------------------------------------------------
# 3) RBAC: Container App MI pode ler secrets do Key Vault
# -------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

# -------------------------------------------------------------------
# 4) Espera de propagação RBAC
# -------------------------------------------------------------------
resource "time_sleep" "wait_for_rbac" {
  create_duration = "${var.rbac_propagation_wait_seconds}s"
  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.kv_secrets_user
  ]
}
