# =============================================================================
# API Management Core Information
# =============================================================================

output "apim_info" {
  description = "API Management details"
  value = {
    name        = azurerm_api_management.apim.name
    id          = azurerm_api_management.apim.id
    gateway_url = azurerm_api_management.apim.gateway_url
    sku_name    = azurerm_api_management.apim.sku_name
    location    = azurerm_api_management.apim.location
  }
}

# =============================================================================
# API Endpoints
# =============================================================================

output "auth_api_info" {
  description = "Auth API details"
  value = {
    name = azurerm_api_management_api.auth_api.name
    id   = azurerm_api_management_api.auth_api.id
    path = azurerm_api_management_api.auth_api.path
  }
}

output "game_api_info" {
  description = "Game API details"
  value = {
    name = azurerm_api_management_api.game_api.name
    id   = azurerm_api_management_api.game_api.id
    path = azurerm_api_management_api.game_api.path
  }
}

output "user_api_info" {
  description = "User API details"
  value = {
    name = azurerm_api_management_api.user_api.name
    id   = azurerm_api_management_api.user_api.id
    path = azurerm_api_management_api.user_api.path
  }
}

# =============================================================================
# API Gateway URLs
# =============================================================================

output "api_gateway_urls" {
  description = "API Gateway endpoint URLs"
  value = {
    base_url = azurerm_api_management.apim.gateway_url
    auth_api = "${azurerm_api_management.apim.gateway_url}/auth"
    game_api = "${azurerm_api_management.apim.gateway_url}/game"
    user_api = "${azurerm_api_management.apim.gateway_url}/user"
  }
}

# =============================================================================
# Deployment Summary
# =============================================================================

output "deployment_summary" {
  description = "High-level summary of the API Gateway deployment"
  value = {
    environment          = local.environment
    location             = azurerm_api_management.apim.location
    resource_group       = azurerm_api_management.apim.resource_group_name
    apim_name            = azurerm_api_management.apim.name
    apis_count           = 3
    deployment_timestamp = timestamp()
  }
}

# =============================================================================
# Deployment Performance Metrics
# =============================================================================

output "deployment_timing" {
  description = "Infrastructure deployment timing information"
  value = {
    terraform_start_time = local.deployment_start_time
    terraform_end_time   = local.deployment_end_time
    note                 = "Terraform timestamps are estimates. Use CI/CD pipeline GITHUB_STEP_SUMMARY for accurate timing."
    measurement_source   = "CI/CD Pipeline"
  }
}

# =============================================================================
# All APIs Summary
# =============================================================================

output "all_apis_summary" {
  description = "Summary of all configured APIs"
  value = {
    auth_api = {
      name = azurerm_api_management_api.auth_api.name
      path = azurerm_api_management_api.auth_api.path
      url  = "${azurerm_api_management.apim.gateway_url}/auth"
    }
    game_api = {
      name = azurerm_api_management_api.game_api.name
      path = azurerm_api_management_api.game_api.path
      url  = "${azurerm_api_management.apim.gateway_url}/game"
    }
    user_api = {
      name = azurerm_api_management_api.user_api.name
      path = azurerm_api_management_api.user_api.path
      url  = "${azurerm_api_management.apim.gateway_url}/user"
    }
  }
}