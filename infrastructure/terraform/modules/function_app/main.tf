# =============================================================================
# Azure Function App Module
# =============================================================================
# This module creates an Azure Function App with the necessary dependencies
# including Storage Account, Application Insights, and Key Vault integration.
# =============================================================================

locals {
  clean_prefix      = replace(replace(var.name_prefix, "--", "-"), "--", "-")
  clean_service     = replace(replace(var.service_name, "--", "-"), "--", "-")
  proposed_name     = "${local.clean_prefix}-${local.clean_service}"
  functionapp_name  = length(local.proposed_name) > 60 ? substr(local.proposed_name, 0, 60) : local.proposed_name
  storage_name      = replace("${local.functionapp_name}storage", "-", "")
}

# =============================================================================
# Storage Account for Azure Functions
# =============================================================================
resource "azurerm_storage_account" "function_storage" {
  name                     = local.storage_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  tags = var.tags
}

# =============================================================================
# Application Insights for Function App
# =============================================================================
resource "azurerm_application_insights" "function_insights" {
  name                = "${local.functionapp_name}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"

  tags = var.tags
}

# =============================================================================
# Azure Function App
# =============================================================================
resource "azurerm_linux_function_app" "main" {
  name                = local.functionapp_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = var.app_service_plan_id

  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key

  site_config {
    application_insights_connection_string = azurerm_application_insights.function_insights.connection_string
    application_insights_key               = azurerm_application_insights.function_insights.instrumentation_key

    application_stack {
      dotnet_version = "9.0"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "AzureWebJobsStorage" = azurerm_storage_account.function_storage.primary_connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.function_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.function_insights.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# =============================================================================
# Key Vault Access Policy for Function App
# =============================================================================
resource "azurerm_key_vault_access_policy" "function_app" {
  count        = var.key_vault_id != null ? 1 : 0
  key_vault_id = var.key_vault_id
  tenant_id     = var.tenant_id
  object_id     = azurerm_linux_function_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# =============================================================================
# Service Bus Connection String Secret
# =============================================================================
resource "azurerm_key_vault_secret" "service_bus_connection" {
  count        = var.key_vault_id != null && var.service_bus_connection_string != null ? 1 : 0
  name         = "ServiceBusConnection"
  value        = var.service_bus_connection_string
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_key_vault_access_policy.function_app]
}

# =============================================================================
# SendGrid API Key Secret
# =============================================================================
resource "azurerm_key_vault_secret" "sendgrid_api_key" {
  count        = var.key_vault_id != null && var.sendgrid_api_key != null ? 1 : 0
  name         = "SENDGRID-API-KEY"
  value        = var.sendgrid_api_key
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_key_vault_access_policy.function_app]
}
