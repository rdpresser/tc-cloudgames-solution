#########################################
# Service Bus Module - Variables
# Defines input parameters for creating
# Azure Service Bus namespace, topic, and subscription
#########################################

variable "name_prefix" {
  description = "The name of the Service Bus Namespace."
  type        = string
  default     = "tccloudgames-sb"
}

variable "location" {
  description = "Azure region for Service Bus namespace."
  type        = string
  default     = "brazilsouth"
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

variable "topic_name" {
  description = "Name of the Service Bus topic."
  type        = string
  default     = "user.events"
}

variable "subscription_name" {
  description = "Name of the subscription for the topic."
  type        = string
  default     = "fanout-subscription"
}

variable "tags" {
  description = "Tags to apply to Service Bus resources."
  type        = map(string)
}
