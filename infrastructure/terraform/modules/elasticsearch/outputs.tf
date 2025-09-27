# =============================================================================
# Elasticsearch Module Outputs
# =============================================================================

# =============================================================================
# Container Group Outputs
# =============================================================================

output "container_group_id" {
  description = "ID of the Elasticsearch container group"
  value       = azurerm_container_group.elasticsearch.id
}

output "container_group_name" {
  description = "Name of the Elasticsearch container group"
  value       = azurerm_container_group.elasticsearch.name
}

output "elasticsearch_fqdn" {
  description = "FQDN of the Elasticsearch container group"
  value       = azurerm_container_group.elasticsearch.fqdn
}

output "elasticsearch_ip_address" {
  description = "Public IP address of the Elasticsearch container group"
  value       = azurerm_container_group.elasticsearch.ip_address
}

# =============================================================================
# Elasticsearch Connection Information
# =============================================================================

output "elasticsearch_url" {
  description = "URL to access Elasticsearch"
  value       = "http://${azurerm_container_group.elasticsearch.fqdn}:9200"
}

output "elasticsearch_host" {
  description = "Hostname of Elasticsearch"
  value       = azurerm_container_group.elasticsearch.fqdn
}

output "elasticsearch_port" {
  description = "Port of Elasticsearch"
  value       = "9200"
}

# =============================================================================
# Kibana Connection Information (if enabled)
# =============================================================================

output "kibana_url" {
  description = "URL to access Kibana (if enabled)"
  value       = var.enable_kibana ? "http://${azurerm_container_group.elasticsearch.fqdn}:5601" : null
}

output "kibana_host" {
  description = "Hostname of Kibana (if enabled)"
  value       = var.enable_kibana ? azurerm_container_group.elasticsearch.fqdn : null
}

output "kibana_port" {
  description = "Port of Kibana (if enabled)"
  value       = var.enable_kibana ? "5601" : null
}

# =============================================================================
# Storage Outputs
# =============================================================================

output "storage_account_name" {
  description = "Name of the storage account for Elasticsearch data"
  value       = azurerm_storage_account.elasticsearch.name
}

output "storage_account_id" {
  description = "ID of the storage account for Elasticsearch data"
  value       = azurerm_storage_account.elasticsearch.id
}

output "storage_share_name" {
  description = "Name of the file share for Elasticsearch data"
  value       = azurerm_storage_share.elasticsearch.name
}

# =============================================================================
# Network Security Group Outputs
# =============================================================================

output "network_security_group_id" {
  description = "ID of the network security group"
  value       = azurerm_network_security_group.elasticsearch.id
}

output "network_security_group_name" {
  description = "Name of the network security group"
  value       = azurerm_network_security_group.elasticsearch.name
}

# =============================================================================
# Monitoring Outputs
# =============================================================================

output "application_insights_id" {
  description = "ID of the Application Insights resource (if monitoring enabled)"
  value       = var.enable_monitoring ? azurerm_application_insights.elasticsearch[0].id : null
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights (if monitoring enabled)"
  value       = var.enable_monitoring ? azurerm_application_insights.elasticsearch[0].instrumentation_key : null
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace (if monitoring enabled)"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.elasticsearch[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace (if monitoring enabled)"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.elasticsearch[0].name : null
}

# =============================================================================
# Connection String for Applications
# =============================================================================

output "connection_string" {
  description = "Connection string for Elasticsearch (for use in applications)"
  value       = "http://${azurerm_container_group.elasticsearch.fqdn}:9200"
}

# =============================================================================
# Health Check Information
# =============================================================================

output "health_check_url" {
  description = "URL for Elasticsearch health check"
  value       = "http://${azurerm_container_group.elasticsearch.fqdn}:9200/_cluster/health"
}

output "cluster_info_url" {
  description = "URL for Elasticsearch cluster information"
  value       = "http://${azurerm_container_group.elasticsearch.fqdn}:9200/_cluster/stats"
}

