locals {
  clean_prefix      = replace(replace(var.name_prefix, "--", "-"), "--", "-")
  clean_service     = replace(replace(var.service_name, "--", "-"), "--", "-")
  proposed_name     = "${local.clean_prefix}-${local.clean_service}"
  containerapp_name = length(local.proposed_name) > 32 ? substr(local.proposed_name, 0, 32) : local.proposed_name

  acr_name = split(".", var.container_registry_server)[0]
}

# 1) Create minimal Container App with System MI, no secrets, public image
resource "azurerm_container_app" "main" {
  name                         = local.containerapp_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.service_name
      image  = var.container_image_placeholder
      cpu    = var.cpu_requests
      memory = var.memory_requests

      dynamic "env" {
        for_each = var.env_plain
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }
  }

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
    create = "30m"  # Container Apps can take a while on first env
    update = "20m"
    delete = "20m"
  }
}

# 2) RBAC: allow Container App MI to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${local.acr_name}"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# 3) RBAC: allow Container App MI to read Key Vault secrets
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.main.identity[0].principal_id

  depends_on = [azurerm_container_app.main]

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# 4) Small wait to let RBAC propagate (reduces flaky 403s from Key Vault / ACR)
resource "time_sleep" "wait_for_rbac" {
  create_duration = "${var.rbac_propagation_wait_seconds}s"
  depends_on      = [azurerm_role_assignment.acr_pull, azurerm_role_assignment.kv_secrets_user]
}

# 5) PATCH the Container App to add:
#    - configuration.secrets with KeyVault references (identity=System)
#    - template.containers[0].env with secretRef
#    - registry with identity=System
#    - image switched to the private ACR image
resource "azapi_update_resource" "containerapp_patch" {
  type      = "Microsoft.App/containerApps@2024-03-01"
  name      = azurerm_container_app.main.name
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {
    properties = {
      configuration = {
        # add registry now that AcrPull is granted
        registries = [
          {
            server   = var.container_registry_server
            identity = "system"
          }
        ]
        # add Key Vault secret refs
        secrets = [
          for k, v in var.kv_secret_refs : {
            name               = k
            keyVaultUrl        = v                # versionless URI
            identity           = "system"         # use System MI
          }
        ]
      }
      template = {
        containers = [
          {
            name  = var.service_name
            image = var.container_image_acr
            resources = {
              cpu    = tonumber(var.cpu_requests)
              memory = var.memory_requests
            }
            env = concat(
              # plain envs
              [
                for e in var.env_plain : {
                  name  = e.name
                  value = e.value
                }
              ],
              # secretRef envs
              [
                for evar, sname in var.env_secret_refs : {
                  name      = evar
                  secretRef = sname
                }
              ]
            )
          }
        ]
        scale = {
          minReplicas = var.min_replicas
          maxReplicas = var.max_replicas
        }
      }
    }
  }

  response_export_values = ["*"]
  depends_on = [
    time_sleep.wait_for_rbac
  ]

  timeouts {
    create = "30m"
    update = "20m"
    delete = "20m"
  }
}
