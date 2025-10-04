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
  description = "Map of topic names to their IDs (includes both created and existing topics)"
  value = merge(
    {
      for topic_name, topic in azurerm_servicebus_topic.this : topic_name => topic.id
    },
    {
      for topic_name, topic in data.azurerm_servicebus_topic.existing : topic_name => topic.id
    }
  )
}

output "topic_names" {
  description = "List of all topic names (both created and existing)"
  value = concat(
    [for topic in azurerm_servicebus_topic.this : topic.name],
    [for topic in data.azurerm_servicebus_topic.existing : topic.name]
  )
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
  description = "Map of subscription rules created (empty if rules are created via application code)"
  value = var.create_sql_filter_rules ? {
    for rule_key, rule in azurerm_servicebus_subscription_rule.sql_filter : rule_key => {
      id          = rule.id
      name        = rule.name
      sql_filter  = rule.sql_filter
    }
  } : {}
}

output "sql_filter_rules_enabled" {
  description = "Whether SQL filter rules are managed by Terraform"
  value       = var.create_sql_filter_rules
}

output "namespace_connection_string" {
  description = "The connection string for the Service Bus namespace."
  value       = azurerm_servicebus_namespace.this.default_primary_connection_string
  sensitive   = true
}

output "namespace_hostname" {
  description = "The hostname of the Service Bus namespace for Managed Identity authentication."
  value       = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "rbac_assignments" {
  description = "Information about RBAC assignments created"
  value = {
    data_owner_assignments = length(azurerm_role_assignment.servicebus_data_owner)
    role_definition       = "Azure Service Bus Data Owner"
    permissions          = "Send + Listen + Manage (includes CreateQueue, CreateTopic)"
  }
}

