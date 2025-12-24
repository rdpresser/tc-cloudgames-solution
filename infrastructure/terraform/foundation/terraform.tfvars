# =============================================================================
# APIs Configuration for APIM
# =============================================================================
# This file contains the APIs configuration for Azure API Management
# Based on the original apis.tfvars.json configuration

apis = {
  users = {
    name         = "users-api"
    display_name = "Users API"
    path         = "users"
    swagger_url  = "https://tc-cloudgames-dev-cr8n-users-api.salmonbeach-dbfa42fd.eastus2.azurecontainerapps.io/swagger/v1/swagger.json"
    # Temporarily disable policies
    # api_policy   = "<policies><inbound><rate-limit-by-key calls='5' renewal-period='60' counter-key='@(context.Request.IpAddress)' /><base /><cors><allowed-origins><origin>*</origin></allowed-origins></cors></inbound><backend><forward-request /><base /></backend><outbound><base /></outbound><on-error /></policies>"
    # operation_policies = {
    #   "GET-users" = "<policies><inbound><base /><set-header name='x-cache' exists-action='override'><value>true</value></set-header></inbound><backend><base /></backend><outbound><base /></outbound></policies>"
    # }
  }
  games = {
    name         = "games-api"
    display_name = "Games API"
    path         = "games"
    swagger_url  = "https://tc-cloudgames-dev-cr8n-games-api.salmonbeach-dbfa42fd.eastus2.azurecontainerapps.io/swagger/v1/swagger.json"
    # Temporarily disable policies
    # api_policy   = "<policies><inbound><rate-limit-by-key calls='5' renewal-period='60' counter-key='@(context.Request.IpAddress)' /><base /><cors><allowed-origins><origin>*</origin></allowed-origins></cors></inbound><backend><forward-request /><base /></backend><outbound><base /></outbound><on-error /></policies>"
    # operation_policies = {
    #   "GET-games" = "<policies><inbound><base /><set-header name='x-cache' exists-action='override'><value>true</value></set-header></inbound><backend><base /></backend><outbound><base /></outbound></policies>"
    # }
  }
}

# NGINX Ingress IP Configuration
# Update this value after running: .\aks-manager.ps1 install-nginx
# Then: terraform apply to update APIM backend

nginx_ingress_ip = "130.213.254.162"

