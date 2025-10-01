variable "name_prefix" {
  description = "Name prefix for Key Vault (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Azure region where the Key Vault will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where the Key Vault will be deployed"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID where the Key Vault will be deployed"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "sku_name" {
  description = "The SKU name of the Key Vault"
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "The number of days that items should be retained for once soft-deleted"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Is Purge Protection enabled for this Key Vault"
  type        = bool
  default     = false
}

variable "tenant_id" {
  description = "The Tenant ID used by the Key Vault"
  type        = string
}

# =============================================================================
# Infrastructure Secrets Variables
# =============================================================================

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
}

variable "acr_login_server" {
  description = "Azure Container Registry login server"
  type        = string
}

variable "acr_admin_username" {
  description = "Azure Container Registry admin username"
  type        = string
}

variable "acr_admin_password" {
  description = "Azure Container Registry admin password"
  type        = string
  sensitive   = true
}

variable "postgres_fqdn" {
  description = "PostgreSQL server FQDN"
  type        = string
}

variable "postgres_admin_login" {
  description = "PostgreSQL admin login"
  type        = string
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "redis_hostname" {
  description = "Redis cache hostname"
  type        = string
}

variable "redis_ssl_port" {
  description = "Redis cache SSL port"
  type        = string
}

variable "redis_primary_access_key" {
  description = "Redis cache primary access key"
  type        = string
  sensitive   = true
}

variable "servicebus_namespace" {
  description = "Service Bus namespace name"
  type        = string
}

# =============================================================================
# RBAC Access Control Variables
# =============================================================================

variable "service_principal_object_id" {
  description = "Object ID of the service principal that needs Key Vault access (replaces app_object_id)"
  type        = string
}

variable "user_object_id" {
  description = "Object ID of the Azure AD user that needs Key Vault access"
  type        = string
  default     = null
}

variable "github_actions_object_id" {
  description = "Object ID of the GitHub Actions service principal"
  type        = string
  default     = null
}

# =============================================================================
# Database Connection Variables (replacing postgres_* pattern)
# =============================================================================

variable "db_host" {
  description = "Database server hostname"
  type        = string
}

variable "db_port" {
  description = "Database server port"
  type        = string
  default     = "5432"
}

variable "db_name_users" {
  description = "Users database name"
  type        = string
  default     = "tc-cloudgames-users-db"
}

variable "db_name_games" {
  description = "Games database name"
  type        = string
  default     = "tc-cloudgames-games-db"
}

variable "db_name_payments" {
  description = "Payments database name"
  type        = string
  default     = "tc-cloudgames-payments-db"
}

variable "db_name_maintenance" {
  description = "Maintenance database name"
  type        = string
  default     = "postgres"
}

variable "db_schema" {
  description = "Maintenance database schema"
  type        = string
  default     = "public"
}

variable "db_connection_timeout" {
  description = "The number of seconds to wait for a connection to the database before timing out"
  type        = number
  default     = 30
}

# =============================================================================
# Cache Connection Variables (replacing redis_* pattern)
# =============================================================================

variable "cache_host" {
  description = "Redis cache hostname"
  type        = string
}

variable "cache_port" {
  description = "Redis cache port"
  type        = string
  default     = "6380"
}

variable "cache_password" {
  description = "Redis cache primary access key"
  type        = string
  sensitive   = true
}

variable "cache_secure" {
  description = "Is SSL enabled for the Redis cache"
  type        = bool
  default     = true
}

variable "cache_users_instance_name" {
  description = "Redis cache instance name for users"
  type        = string
  default     = "tc-cloudgames-users-cache"
}

variable "cache_games_instance_name" {
  description = "Redis cache instance name for games"
  type        = string
  default     = "tc-cloudgames-games-cache"
}

variable "cache_payments_instance_name" {
  description = "Redis cache instance name for payments"
  type        = string
  default     = "tc-cloudgames-payments-cache"
}

# =============================================================================
# Service Bus Connection Variables  
# =============================================================================

variable "servicebus_connection_string" {
  description = "Service Bus connection string"
  type        = string
  sensitive   = true
}

variable "servicebus_auto_provision" {
  description = "Service Bus auto provision setting"
  type        = bool
  default     = true
}

variable "servicebus_max_delivery_count" {
  description = "Service Bus maximum delivery count"
  type        = number
  default     = 10
}

variable "servicebus_enable_dead_lettering" {
  description = "Service Bus enable dead lettering"
  type        = bool
  default     = true
}

variable "servicebus_auto_purge_on_startup" {
  description = "Service Bus auto purge on startup"
  type        = bool
  default     = false
}

variable "servicebus_use_control_queues" {
  description = "Service Bus use control queues"
  type        = bool
  default     = true
}

variable "servicebus_users_topic_name" {
  description = "Service Bus users topic name"
  type        = string
  default     = "user.events"
}

variable "servicebus_games_topic_name" {
  description = "Service Bus games topic name"
  type        = string
  default     = "game.events"
}

variable "servicebus_payments_topic_name" {
  description = "Service Bus payments topic name"
  type        = string
  default     = "payment.events"
}

# =============================================================================
# Legacy Variables (keeping for backward compatibility)
# =============================================================================

variable "subscription_id" {
  description = "Azure subscription ID for role assignments"
  type        = string
}

# =============================================================================
# ELASTICSEARCH Variables
# =============================================================================
variable "elasticsearch_game_endpoint" {
  type        = string
  description = "Elasticsearch endpoint URL"
}

variable "elasticsearch_game_apikey" {
  type        = string
  description = "Elasticsearch API key"
  sensitive   = true
}

variable "elasticsearch_game_projectid" {
  type        = string
  description = "Elasticsearch project ID"
}

variable "elasticsearch_game_indexprefix" {
  type        = string
  description = "Elasticsearch index name prefix"
}