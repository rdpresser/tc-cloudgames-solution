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
  
  # Generate storage name (max 24 chars, lowercase, no hyphens)
  base_name = replace(replace(var.name_prefix, "-", ""), "_", "")
  storage_name = substr("${lower(local.base_name)}st", 0, 24)
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
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "AzureWebJobsStorage" = azurerm_storage_account.function_storage.primary_connection_string
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.function_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.function_insights.connection_string
    
    # Key Vault references for sensitive data
    "SENDGRID_API_KEY" = "@Microsoft.KeyVault(VaultName=${split(".", split("/", var.key_vault_uri)[2])[0]};SecretName=sendgrid-api-key)"
    "SENDGRID_EMAIL_NEW_USER_TID" = "@Microsoft.KeyVault(VaultName=${split(".", split("/", var.key_vault_uri)[2])[0]};SecretName=sendgrid-email-new-user-tid)"
    "SENDGRID_EMAIL_PURCHASE_TID" = "@Microsoft.KeyVault(VaultName=${split(".", split("/", var.key_vault_uri)[2])[0]};SecretName=sendgrid-email-purchase-tid)"
    
    # Service Bus settings - usando Key Vault reference como fallback
    "SERVICEBUS_CONNECTION" = "@Microsoft.KeyVault(VaultName=${split(".", split("/", var.key_vault_uri)[2])[0]};SecretName=servicebus-connection-string)"
    "SERVICEBUS_NAMESPACE" = "@Microsoft.KeyVault(VaultName=${split(".", split("/", var.key_vault_uri)[2])[0]};SecretName=servicebus-namespace)"
    
    # CRÍTICO: Service Bus Trigger com Managed Identity requer esta configuração
    # Permite que triggers usem Managed Identity automaticamente
    "AzureWebJobsServiceBus__fullyQualifiedNamespace" = "@Microsoft.KeyVault(VaultName=${split(".", split("/", var.key_vault_uri)[2])[0]};SecretName=servicebus-namespace)"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to app_settings that Azure might modify automatically
      app_settings["WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"],
      app_settings["WEBSITE_CONTENTSHARE"],
      # Azure may stamp or regenerate these; avoid perpetual drift/noise
      app_settings["APPINSIGHTS_INSTRUMENTATIONKEY"],
      app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"],
      app_settings["AzureWebJobsStorage"],
      app_settings["FUNCTIONS_EXTENSION_VERSION"],
      
      # Ignore hidden tags that Azure adds automatically
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      
      # Ignore automatic site_config changes
      site_config[0].scm_use_main_ip_restriction,
      site_config[0].use_32_bit_worker,
      site_config[0].websockets_enabled,
      site_config[0].always_on,
      site_config[0].default_documents,
      site_config[0].http2_enabled,
      site_config[0].managed_pipeline_mode,
      site_config[0].minimum_tls_version,
      site_config[0].remote_debugging_enabled,
      site_config[0].ftps_state
    ]
  }
}

# =============================================================================
# RBAC Role Assignments for Function App
# =============================================================================

# Key Vault Access
resource "azurerm_role_assignment" "function_app_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Service Bus Access (if Service Bus ID is provided)
resource "azurerm_role_assignment" "function_app_servicebus_data_owner" {
  count                = var.servicebus_namespace_id != null ? 1 : 0
  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}
