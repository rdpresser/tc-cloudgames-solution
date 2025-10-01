provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

# =============================================================================
# Deployment Timing - Start Timestamp
# =============================================================================
locals {
  deployment_start_time = timestamp()
}

# =============================================================================
# Random suffix for unique naming
# =============================================================================
resource "random_string" "unique_suffix" {
  length  = 4
  upper   = false
  special = false
}

# =============================================================================
# Locals: naming and common tags
# =============================================================================
locals {
  environment  = var.environment
  project_name = var.project_name
  name_prefix  = "${local.project_name}-${local.environment}"
  full_name    = "${local.name_prefix}-${random_string.unique_suffix.result}"

  apim_name = "tc-cloudgames-${local.environment}-apim-${random_string.unique_suffix.result}"

  common_tags = {
    Environment = local.environment
    Project     = "TC Cloud Games"
    ManagedBy   = "Terraform"
    Owner       = "DevOps Team"
    CostCenter  = "Engineering"
    Workspace   = terraform.workspace
    Provider    = "Azure"
    Component   = "API Gateway"
  }
}

# =============================================================================
# API Management
# =============================================================================
resource "azurerm_api_management" "apim" {
  name                = local.apim_name
  location            = var.foundation_resource_group_location
  resource_group_name = var.foundation_resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku_name

  tags = local.common_tags
}

# =============================================================================
# Auth API
# =============================================================================
resource "azurerm_api_management_api" "auth_api" {
  name                = "auth-api"
  resource_group_name = azurerm_api_management.apim.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Auth API"
  path                = "auth"
  protocols           = ["https"]

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/TC.CloudGames Auth.openapi+json.json")
  }

  depends_on = [azurerm_api_management.apim]
}

# =============================================================================
# Game API
# =============================================================================
resource "azurerm_api_management_api" "game_api" {
  name                = "game-api"
  resource_group_name = azurerm_api_management.apim.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Game API"
  path                = "game"
  protocols           = ["https"]

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/TC.CloudGames Game.openapi+json.json")
  }

  depends_on = [azurerm_api_management.apim]
}

# =============================================================================
# User API
# =============================================================================
resource "azurerm_api_management_api" "user_api" {
  name                = "user-api"
  resource_group_name = azurerm_api_management.apim.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "User API"
  path                = "user"
  protocols           = ["https"]

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/TC.CloudGames User.openapi+json.json")
  }

  depends_on = [azurerm_api_management.apim]
}

# =============================================================================
# Rate Limiting Policies
# =============================================================================

# Auth API - 5 calls per minute
resource "azurerm_api_management_api_policy" "auth_api_rate_limit" {
  api_name            = azurerm_api_management_api.auth_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_api_management.apim.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <rate-limit-by-key calls="5" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
        <base />
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound />
    <on-error />
</policies>
XML

  depends_on = [azurerm_api_management_api.auth_api]
}

# User API - 100 calls per minute
resource "azurerm_api_management_api_policy" "user_api_rate_limit" {
  api_name            = azurerm_api_management_api.user_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_api_management.apim.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
        <base />
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound />
    <on-error />
</policies>
XML

  depends_on = [azurerm_api_management_api.user_api]
}

# Game API - 1000 calls per minute
resource "azurerm_api_management_api_policy" "game_api_rate_limit" {
  api_name            = azurerm_api_management_api.game_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_api_management.apim.resource_group_name

  xml_content = <<XML
<policies>
    <inbound>
        <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
        <base />
    </inbound>
    <backend>
        <forward-request />
    </backend>
    <outbound />
    <on-error />
</policies>
XML

  depends_on = [azurerm_api_management_api.game_api]
}

# =============================================================================
# Deployment Timing - End Timestamp and Duration Calculation
# =============================================================================
locals {
  deployment_end_time = timestamp()

  # Calculate duration in seconds (approximation since both timestamps are taken at plan time)
  # Note: This gives an estimate since both timestamps are captured during planning phase
  # For more accurate measurement, use external timing in CI/CD pipeline
  deployment_duration_estimate = "Measured by CI/CD pipeline for accurate timing"
}

# =============================================================================
# OpenAPI Files Validation
# =============================================================================

locals {
  openapi_files = [
    "TC.CloudGames Auth.openapi+json.json",
    "TC.CloudGames Game.openapi+json.json", 
    "TC.CloudGames User.openapi+json.json"
  ]
}

resource "null_resource" "validate_openapi_files" {
  count = var.validate_openapi_files ? 1 : 0

  for_each = toset(local.openapi_files)

  provisioner "local-exec" {
    command = "test -f '${path.module}/${each.value}' || (echo 'OpenAPI file ${each.value} not found' && exit 1)"
  }
}

