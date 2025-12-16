locals {
  base_backend_url = (
    var.backend_url != null && trimspace(var.backend_url) != ""
  ) ? var.backend_url : "http://example.com"
}

resource "azurerm_api_management" "this" {
  name                = "${var.name_prefix}-apim"
  location            = var.location
  resource_group_name = var.resource_group_name

  publisher_name  = var.publisher_name
  publisher_email = var.publisher_email

  sku_name = var.sku_name
  tags     = var.tags
}

# =============================================================================
# Backends - AKS Ingress Endpoints
# =============================================================================

resource "azurerm_api_management_backend" "games_api" {
  name                = "aks-games-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "${local.base_backend_url}/games"
  title               = "AKS Games API Backend"
  description         = "Backend pointing to Games API in AKS"
}

resource "azurerm_api_management_backend" "user_api" {
  name                = "aks-user-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "${local.base_backend_url}/user"
  title               = "AKS User API Backend"
  description         = "Backend pointing to User API in AKS"
}

resource "azurerm_api_management_backend" "payments_api" {
  name                = "aks-payments-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  protocol            = "http"
  url                 = "${local.base_backend_url}/payments"
  title               = "AKS Payments API Backend"
  description         = "Backend pointing to Payments API in AKS"
}

# =============================================================================
# APIs - CloudGames APIs
# =============================================================================

resource "azurerm_api_management_api" "games_api" {
  name                = "games-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Games API"
  path                = "games"
  protocols           = ["https", "http"]
  service_url         = "${local.base_backend_url}/games"
  description         = "API for game management"
  
  subscription_required = var.require_subscription
}

resource "azurerm_api_management_api" "user_api" {
  name                = "user-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "User API"
  path                = "user"
  protocols           = ["https", "http"]
  service_url         = "${local.base_backend_url}/user"
  description         = "API for user management"
  
  subscription_required = var.require_subscription
}

resource "azurerm_api_management_api" "payments_api" {
  name                = "payments-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = "Payments API"
  path                = "payments"
  protocols           = ["https", "http"]
  service_url         = "${local.base_backend_url}/payments"
  description         = "API for payment processing"
  
  subscription_required = var.require_subscription
}

# =============================================================================
# API Operations - Wildcard for all operations
# =============================================================================

// No explicit API operations are required; policies route to backends.

# =============================================================================
# API Policies - CORS and Backend Routing
# =============================================================================

resource "azurerm_api_management_api_policy" "games_policy" {
  api_name            = azurerm_api_management_api.games_api.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="aks-games-backend" />
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>*</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [azurerm_api_management_backend.games_api]
}

resource "azurerm_api_management_api_policy" "user_policy" {
  api_name            = azurerm_api_management_api.user_api.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="aks-user-backend" />
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>*</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [azurerm_api_management_backend.user_api]
}

resource "azurerm_api_management_api_policy" "payments_policy" {
  api_name            = azurerm_api_management_api.payments_api.name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="aks-payments-backend" />
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>*</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [azurerm_api_management_backend.payments_api]
}
