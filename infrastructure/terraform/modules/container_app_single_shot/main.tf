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

  # Estratégia única: use_hello_world_images controla Container Apps
  # true  = Hello World (sem ACR pull, sem Key Vault) - primeira execução
  # false = Produção (com ACR pull, com Key Vault) - execuções posteriores
  # 
  # IMPORTANTE: GitHub Actions ACR push permissions são sempre ativas
  # para permitir que pipeline funcione mesmo na primeira execução
  enable_acr_pull   = !var.use_hello_world_images
  enable_key_vault  = !var.use_hello_world_images
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
  # Pipeline manages image updates after initial deployment
  # -------------------------------------------------------------------
  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.service_name
      image  = var.use_hello_world_images ? var.container_image_placeholder : var.container_image_acr
      cpu    = var.cpu_requests
      memory = var.memory_requests
    }
  }

  # -------------------------------------------------------------------
  # Lifecycle: Pipeline manages images and environment variables
  # This allows the pipeline to manage both image updates and env vars without Terraform interference
  # Terraform manages infrastructure, pipeline manages application deployment configuration
  # -------------------------------------------------------------------
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env
    ]
  }

  # -------------------------------------------------------------------
  # Container Registry Configuration (condicional)
  # Só habilita ACR quando não estiver usando hello-world images
  # -------------------------------------------------------------------
  dynamic "registry" {
    for_each = local.enable_acr_pull ? [1] : []
    content {
      server   = var.container_registry_server
      identity = "System"
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
  # Key Vault Secret References (condicional)
  # Só cria secrets quando não estiver usando hello-world images
  # -------------------------------------------------------------------
  dynamic "secret" {
    for_each = local.enable_key_vault ? [
      {
        name = "db-host"
        path = "db-host"
      },
      {
        name = "db-port"
        path = "db-port"
      },
      {
        name = var.db_name_secret_ref
        path = var.db_name_secret_ref
      },
      {
        name = "db-admin-login"
        path = "db-admin-login"
      },
      {
        name = "db-password"
        path = "db-password"
      },
      {
        name = "db-name-maintenance"
        path = "db-name-maintenance"
      },
      {
        name = "db-schema"
        path = "db-schema"
      },
      {
        name = "db-connection-timeout"
        path = "db-connection-timeout"
      },
      {
        name = "cache-host"
        path = "cache-host"
      },
      {
        name = "cache-port"
        path = "cache-port"
      },
      {
        name = "cache-password"
        path = "cache-password"
      },
      {
        name = "cache-secure"
        path = "cache-secure"
      },
      {
        name = "servicebus-connection-string"
        path = "servicebus-connection-string"
      },
      {
        name = "servicebus-auto-provision"
        path = "servicebus-auto-provision"
      },
      {
        name = "servicebus-max-delivery-count"
        path = "servicebus-max-delivery-count"
      },
      {
        name = "servicebus-enable-dead-lettering"
        path = "servicebus-enable-dead-lettering"
      },
      {
        name = "servicebus-auto-purge-on-startup"
        path = "servicebus-auto-purge-on-startup"
      },
      {
        name = "servicebus-use-control-queues"
        path = "servicebus-use-control-queues"
      }
    ] : []

    content {
      name                = secret.value.name
      key_vault_secret_id = "${var.key_vault_uri}/secrets/${secret.value.path}"
      identity            = "System"
    }
  }

  timeouts {
    create = var.timeouts_create
    update = var.timeouts_update
    delete = var.timeouts_delete
  }
}

# -------------------------------------------------------------------
# RBAC Assignments (condicionais)
# Só cria quando não estiver usando hello-world images
# -------------------------------------------------------------------
resource "azurerm_role_assignment" "acr_pull" {
  count                = local.enable_acr_pull ? 1 : 0
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  count                = local.enable_key_vault ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]
}

# -------------------------------------------------------------------
# Espera de propagação RBAC (condicional)
# -------------------------------------------------------------------
resource "time_sleep" "wait_for_rbac" {
  count           = local.enable_acr_pull || local.enable_key_vault ? 1 : 0
  create_duration = "${var.rbac_propagation_wait_seconds}s"
  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.kv_secrets_user
  ]
}
