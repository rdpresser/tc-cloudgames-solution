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
  description = "List of Service Bus topics with creation control. Each topic can specify whether it should be created by Terraform or not."
  type = list(object({
    name   = string
    create = bool
  }))
  default = []
}

variable "topic_subscriptions" {
  description = "Map of topic names to their subscription configurations. Leave empty if subscriptions will be created via application code."
  type = map(object({
    subscription_name = string
    sql_filter_rules = optional(map(object({
      filter_expression = string
      action            = optional(string, "")
      rule_name         = optional(string, "SqlFilter")
    })), {})
  }))
  default = {}
}

variable "managed_identity_principal_ids" {
  description = "List of Managed Identity Principal IDs that need Azure Service Bus Data Owner permissions"
  type        = list(string)
  default     = []
}

variable "create_sql_filter_rules" {
  description = "Whether to create SQL filter rules via Terraform. Set to false if rules will be created via application code."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to Service Bus resources."
  type        = map(string)
}
