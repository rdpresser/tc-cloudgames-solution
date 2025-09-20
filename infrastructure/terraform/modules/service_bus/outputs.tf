#########################################
# Service Bus Module - Outputs
# Exports useful values for integration
#########################################

output "namespace_name" {
  description = "The name of the Service Bus namespace."
  value       = azurerm_servicebus_namespace.this.name
}

output "namespace_id" {
  description = "The ID of the Service Bus namespace."
  value       = azurerm_servicebus_namespace.this.id
}

output "topic_ids" {
  description = "Map of topic names to their IDs"
  value = {
    for topic_name, topic in azurerm_servicebus_topic.this : topic_name => topic.id
  }
}

output "topic_names" {
  description = "List of created topic names"
  value       = [for topic in azurerm_servicebus_topic.this : topic.name]
}

output "subscription_ids" {
  description = "Map of topic names to their subscription IDs"
  value = {
    for topic_name, subscription in azurerm_servicebus_subscription.this : topic_name => subscription.id
  }
}

output "subscription_names" {
  description = "Map of topic names to their subscription names"
  value = {
    for topic_name, subscription in azurerm_servicebus_subscription.this : topic_name => subscription.name
  }
}

output "subscription_rules" {
  description = "Map of subscription rules created"
  value = {
    for rule_key, rule in azurerm_servicebus_subscription_rule.sql_filter : rule_key => {
      id          = rule.id
      name        = rule.name
      sql_filter  = rule.sql_filter
    }
  }
}

output "namespace_connection_string" {
  description = "The connection string for the Service Bus namespace."
  value       = azurerm_servicebus_namespace.this.default_primary_connection_string
  sensitive   = true
}

