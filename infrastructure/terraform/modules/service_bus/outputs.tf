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

output "topic_name" {
  description = "The name of the Service Bus topic."
  value       = azurerm_servicebus_topic.this.name
}

output "subscription_name" {
  description = "The name of the Service Bus subscription."
  value       = azurerm_servicebus_subscription.this.name
}

