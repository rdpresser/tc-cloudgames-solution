# =============================================================================
# Key Vault
# =============================================================================

resource "azurerm_key_vault" "key_vault" {
  name                       = "${var.name_prefix}kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = var.soft_delete_retention_days

  # Enable RBAC for Container Apps Managed Identity integration
  rbac_authorization_enabled = true
  purge_protection_enabled   = var.purge_protection_enabled

  # Allow Container Apps to access
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# =============================================================================
# Infrastructure Configuration Secrets (for CI/CD and Container Apps)
# =============================================================================

resource "azurerm_key_vault_secret" "acr_name" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "acr-name"
  value        = var.acr_name

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin
  ]
}

resource "azurerm_key_vault_secret" "acr_login_server" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "acr-login-server"
  value        = var.acr_login_server

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "acr_admin_username" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "acr-username"
  value        = var.acr_admin_username

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "acr_admin_password" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "acr-password"
  value        = var.acr_admin_password

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

# =============================================================================
# Database Configuration Secrets
# =============================================================================

resource "azurerm_key_vault_secret" "db_host" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-host"
  value        = var.postgres_fqdn

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "db_port" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-port"
  value        = var.postgres_port

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "db_name_users" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-users"
  value        = var.postgres_users_db_name

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "db_name_games" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-games"
  value        = var.postgres_games_db_name

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "db_name_payments" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-name-payments"
  value        = var.postgres_payments_db_name

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "db_admin_login" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-admin-login"
  value        = var.postgres_admin_login

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "db_password" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "db-password"
  value        = var.postgres_admin_password

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

# =============================================================================
# Redis Cache Configuration Secrets
# =============================================================================

resource "azurerm_key_vault_secret" "cache_host" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-host"
  value        = var.redis_hostname

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "cache_port" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-port"
  value        = var.redis_ssl_port

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

resource "azurerm_key_vault_secret" "cache_password" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "cache-password"
  value        = var.redis_primary_access_key

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

# =============================================================================
# Service Bus Configuration Secrets
# =============================================================================

resource "azurerm_key_vault_secret" "servicebus_namespace" {
  key_vault_id = azurerm_key_vault.key_vault.id
  name         = "servicebus-namespace"
  value        = var.servicebus_namespace

  depends_on = [
    azurerm_key_vault.key_vault,
    azurerm_role_assignment.app_kv_admin,
    azurerm_role_assignment.app_kv_secrets_user
  ]
}

# =============================================================================
# RBAC Role Assignments for Key Vault Access
# =============================================================================

# 🔑 Application Service Principal - Key Vault Secrets User + Key Vault Administrator
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_object_id

  depends_on = [azurerm_key_vault.key_vault]
}

resource "azurerm_role_assignment" "app_kv_admin" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Administrator" 
  principal_id         = var.app_object_id

  depends_on = [azurerm_key_vault.key_vault]
}

# 👤 User - Key Vault Administrator (optional)
resource "azurerm_role_assignment" "user_kv_admin" {
  count                = var.user_object_id != null ? 1 : 0
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.user_object_id

  depends_on = [azurerm_key_vault.key_vault]
}

# 🤖 GitHub Actions Service Principal - Key Vault Secrets User (optional)  
resource "azurerm_role_assignment" "github_kv_secrets_user" {
  count                = var.github_actions_object_id != null ? 1 : 0
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.github_actions_object_id

  depends_on = [azurerm_key_vault.key_vault]
}
