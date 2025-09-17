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
  description = "Map of topic names to their associated subscriptions. Key is topic name, value is subscription name."
  type        = map(string)
  default = {
    "user-events" = "fanout-subscription"
  }
}

variable "tags" {
  description = "Tags to apply to Service Bus resources."
  type        = map(string)
}
