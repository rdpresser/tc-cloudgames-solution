#########################################
# Service Bus Module - Variables
# Defines input parameters for creating
# Azure Service Bus namespace, topic, and subscription
#########################################

variable "name_prefix" {
  description = "The name of the Service Bus Namespace."
  type        = string
}

variable "location" {
  description = "Azure region for Service Bus namespace."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where Service Bus will be created."
  type        = string
}

variable "sku" {
  description = "Pricing tier for Service Bus Namespace."
  type        = string
  default     = "Standard"
}

variable "topics" {
  description = "List of Service Bus topics to create."
  type        = list(string)
  default     = ["user-events"]
}

variable "topic_subscriptions" {
  description = "Map of topic names to their subscription configurations. Each subscription can have a name and optional SQL filter rules."
  type = map(object({
    subscription_name = string
    sql_filter_rules = optional(map(object({
      filter_expression = string
      action            = optional(string, "")
    })), {})
  }))
  default = {
    "user-events" = {
      subscription_name = "fanout-subscription"
      sql_filter_rules  = {}
    }
  }
}

variable "tags" {
  description = "Tags to apply to Service Bus resources."
  type        = map(string)
}
