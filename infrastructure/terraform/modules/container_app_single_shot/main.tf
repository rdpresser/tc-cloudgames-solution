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
  # Pipeline manages image updates after initial deployment
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
  # Lifecycle: Pipeline manages images and environment variables
  # This allows the pipeline to manage both image updates and env vars without Terraform interference
  # Terraform manages infrastructure, pipeline manages application deployment configuration
  # -------------------------------------------------------------------
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env,
      secret  # Pipeline manages secret references via env vars
    ]
  }

  # -------------------------------------------------------------------
  # Container Registry Configuration (System Identity authentication)
  # Uses the Container App's System Assigned Managed Identity for ACR authentication
  # "System" indicates the system-assigned managed identity should be used
  # -------------------------------------------------------------------
  registry {
    server   = var.container_registry_server
    identity = "System"
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

# -------------------------------------------------------------------
# 5) RBAC propagation complete marker
# This ensures RBAC permissions are ready before Container App operations
# -------------------------------------------------------------------
