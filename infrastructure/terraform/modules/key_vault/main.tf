# =============================================================================
# Key Vault with Terraform RBAC Approach
# 1. Create Key Vault with RBAC enabled
# 2. Create RBAC role assignments 
# 3. Create secrets (after permissions are granted)
# =============================================================================

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Key Vault (RBAC Enabled)
# -----------------------------------------------------------------------------
resource "azurerm_key_vault" "key_vault" {
  name                       = "${var.name_prefix}kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # CRITICAL: Enable RBAC authorization (not Access Policies)
  rbac_authorization_enabled = true

  # Network access configuration
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# RBAC Role Assignments (Foundation Level)
# These must be created BEFORE secrets to ensure proper permissions
# -----------------------------------------------------------------------------

# Service Principal - Key Vault Administrator (can manage secrets)
resource "azurerm_role_assignment" "service_principal_kv_admin" {
  count                = var.service_principal_object_id != null ? 1 : 0
  principal_id         = var.service_principal_object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.key_vault.id
}

# Service Principal - Key Vault Secrets User (can read secrets) 
resource "azurerm_role_assignment" "service_principal_kv_secrets_user" {
  count                = var.service_principal_object_id != null ? 1 : 0
  principal_id         = var.service_principal_object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.key_vault.id
}

# GitHub Actions Service Principal - Key Vault Secrets User
resource "azurerm_role_assignment" "github_actions_kv_secrets_user" {
  count                = var.github_actions_object_id != null ? 1 : 0
  principal_id         = var.github_actions_object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.key_vault.id
}

# User Account - Key Vault Administrator
resource "azurerm_role_assignment" "user_kv_admin" {
  count                = var.user_object_id != null ? 1 : 0
  principal_id         = var.user_object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.key_vault.id
}

# -----------------------------------------------------------------------------
# ACR Role Assignments for CI/CD Pipeline
# -----------------------------------------------------------------------------

# GitHub Actions Service Principal - ACR Push (for CI/CD image push)
resource "azurerm_role_assignment" "github_actions_acr_push" {
  count                = var.github_actions_object_id != null ? 1 : 0
  principal_id         = var.github_actions_object_id
  role_definition_name = "AcrPush"
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${var.acr_name}"
}

# -----------------------------------------------------------------------------
# Key Vault Secrets (Created AFTER RBAC permissions)
# -----------------------------------------------------------------------------

# Infrastructure Secrets
resource "azurerm_key_vault_secret" "acr_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "acr-name"
  value        = var.acr_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "acr-login-server"
  value        = var.acr_login_server

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

# Database Secrets
resource "azurerm_key_vault_secret" "db_host" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-host"
  value        = var.db_host

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_port" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-port"
  value        = var.db_port

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_name_users" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-users"
  value        = var.db_name_users

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_name_games" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-games"
  value        = var.db_name_games

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_name_payments" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-payments"
  value        = var.db_name_payments

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_name_maintenance" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-maintenance"
  value        = var.db_name_maintenance

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_schema" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-schema"
  value        = var.db_schema

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_connection_timeout" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-connection-timeout"
  value        = var.db_connection_timeout

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_admin_login" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-admin-login"
  value        = var.postgres_admin_login

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "db_password" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-password"
  value        = var.postgres_admin_password

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

# Cache Secrets
resource "azurerm_key_vault_secret" "cache_host" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-host"
  value        = var.cache_host

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "cache_port" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-port"
  value        = var.cache_port

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "cache_password" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-password"
  value        = var.cache_password

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "cache_secure" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-secure"
  value        = var.cache_secure

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "cache_users_instance_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-users-instance-name"
  value        = var.cache_users_instance_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "cache_games_instance_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-games-instance-name"
  value        = var.cache_games_instance_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "cache_payments_instance_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-payments-instance-name"
  value        = var.cache_payments_instance_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

# Elasticsearch Secrets
resource "azurerm_key_vault_secret" "elasticsearch_url" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "elasticsearch-url"
  value        = var.elasticsearch_url

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "elasticsearch_host" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "elasticsearch-host"
  value        = var.elasticsearch_host

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "elasticsearch_port" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "elasticsearch-port"
  value        = var.elasticsearch_port

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

# Service Bus Secrets
resource "azurerm_key_vault_secret" "servicebus_namespace" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-namespace"
  value        = var.servicebus_namespace

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_connection_string" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-connection-string"
  value        = var.servicebus_connection_string

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_auto_provision" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-auto-provision"
  value        = tostring(var.servicebus_auto_provision)

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_max_delivery_count" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-max-delivery-count"
  value        = tostring(var.servicebus_max_delivery_count)

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_enable_dead_lettering" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-enable-dead-lettering"
  value        = tostring(var.servicebus_enable_dead_lettering)

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_auto_purge_on_startup" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-auto-purge-on-startup"
  value        = tostring(var.servicebus_auto_purge_on_startup)

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_use_control_queues" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-use-control-queues"
  value        = tostring(var.servicebus_use_control_queues)

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_users_topic_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-users-topic-name"
  value        = var.servicebus_users_topic_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_games_topic_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-games-topic-name"
  value        = var.servicebus_games_topic_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "servicebus_payments_topic_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-payments-topic-name"
  value        = var.servicebus_payments_topic_name

  depends_on = [
    azurerm_role_assignment.service_principal_kv_admin
  ]
}