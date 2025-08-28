// -----------------------------------------------------------------------------
// Redis module outputs
// -----------------------------------------------------------------------------

output "redis_id" {
  description = "The ID of the Redis Cache instance"
  value       = azurerm_redis_cache.redis.id
}

output "redis_name" {
  description = "The name of the Redis Cache instance"
  value       = azurerm_redis_cache.redis.name
}

output "redis_hostname" {
  description = "The hostname of the Redis Cache instance"
  value       = azurerm_redis_cache.redis.hostname
}

output "redis_ssl_port" {
  description = "SSL port of the Redis Cache instance"
  value       = azurerm_redis_cache.redis.ssl_port
}

output "redis_primary_access_key" {
  description = "Primary access key for Redis Cache"
  value       = azurerm_redis_cache.redis.primary_access_key
  sensitive   = true
}

output "redis_sku" {
  value       = azurerm_redis_cache.redis.sku_name
  description = "The SKU of the Redis Cache instance"
}