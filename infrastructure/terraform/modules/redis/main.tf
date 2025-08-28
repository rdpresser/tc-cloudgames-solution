// -----------------------------------------------------------------------------
// Redis Cache Module
// Deploys a Redis Cache instance with configurable SKU and secure defaults
// -----------------------------------------------------------------------------

resource "azurerm_redis_cache" "redis" {
  name                = "${var.name_prefix}-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.sku_capacity
  family              = var.sku_family
  sku_name            = var.sku_name

  // Security settings
  non_ssl_port_enabled = var.enable_non_ssl_port
  minimum_tls_version  = "1.2"

  // Networking settings
  public_network_access_enabled = true

  // Redis configuration
  redis_configuration {
    // Use Azure optimal defaults
    maxmemory_policy = "volatile-lru"
  }

  tags = var.tags
}
