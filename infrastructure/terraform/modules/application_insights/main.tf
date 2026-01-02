// -----------------------------------------------------------------------------
// Application Insights Module
// Deploys Azure Application Insights with workspace-based mode for APM
// Integrates with OpenTelemetry via Azure.Monitor.OpenTelemetry.AspNetCore
// -----------------------------------------------------------------------------

resource "azurerm_application_insights" "main" {
  name                = "${var.name_prefix}-appinsights"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"

  # Sampling percentage (0-100). 100 = no sampling (all data collected)
  sampling_percentage = var.sampling_percentage

  # Daily data cap in GB (0 = no cap)
  daily_data_cap_in_gb = var.daily_data_cap_in_gb > 0 ? var.daily_data_cap_in_gb : null

  # Disable IP masking for better debugging (set to true in production if required)
  disable_ip_masking = var.disable_ip_masking

  # Internet query enabled for external access
  internet_query_enabled = var.internet_query_enabled

  # Local authentication enabled (for connection string auth)
  local_authentication_disabled = false

  tags = var.tags
}
