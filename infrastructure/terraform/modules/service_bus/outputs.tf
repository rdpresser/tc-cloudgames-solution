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
  description = "Map of subscription names to their IDs"
  value = {
    for subscription_name, subscription in azurerm_servicebus_subscription.this : subscription_name => subscription.id
  }
}

output "subscription_names" {
  description = "List of created subscription names"
  value       = [for subscription in azurerm_servicebus_subscription.this : subscription.name]
}

output "namespace_connection_string" {
  description = "The connection string for the Service Bus namespace."
  value       = azurerm_servicebus_namespace.this.default_primary_connection_string
  sensitive   = true
}

