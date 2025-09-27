#########################################
# Service Bus Module - Main (ajustado)
#########################################

resource "azurerm_servicebus_namespace" "this" {
  name                = "${var.name_prefix}-sbus"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  # Apenas esse atributo segue válido
  public_network_access_enabled = true

  tags = var.tags
}

# =============================================================================
# RBAC: Azure Service Bus Data Owner para Managed Identities
# Permite que as aplicações com Managed Identity criem filas, tópicos e subscriptions
# =============================================================================
resource "azurerm_role_assignment" "servicebus_data_owner" {
  count                = length(var.managed_identity_principal_ids)
  principal_id         = var.managed_identity_principal_ids[count.index]
  role_definition_name = "Azure Service Bus Data Owner"
  scope                = azurerm_servicebus_namespace.this.id
}

# =============================================================================
# Topics (Opcionais - podem ser criados via código C#)
# =============================================================================
resource "azurerm_servicebus_topic" "this" {
  for_each     = length(var.topics) > 0 ? toset(var.topics) : toset([])
  name         = each.value
  namespace_id = azurerm_servicebus_namespace.this.id

  # Correto nas versões novas
  partitioning_enabled  = true
  default_message_ttl   = "P7D" # 7 dias
}

# =============================================================================
# Subscriptions (Opcionais - podem ser criadas via código C#)
# =============================================================================
resource "azurerm_servicebus_subscription" "this" {
  for_each = length(var.topic_subscriptions) > 0 ? var.topic_subscriptions : {}
  name     = each.value.subscription_name
  topic_id = azurerm_servicebus_topic.this[each.key].id

  max_delivery_count = 10
  lock_duration      = "PT1M"
}

# =============================================================================
# SQL Filter Rules (Opcionais - podem ser criadas via código C#)
# =============================================================================
resource "azurerm_servicebus_subscription_rule" "sql_filter" {
  for_each = var.create_sql_filter_rules ? {
    for topic_key, subscription in var.topic_subscriptions : topic_key => subscription
    if length(subscription.sql_filter_rules) > 0
  } : {}

  name            = "SqlFilter"
  subscription_id = azurerm_servicebus_subscription.this[each.key].id
  filter_type     = "SqlFilter"
  sql_filter      = values(each.value.sql_filter_rules)[0].filter_expression
  action          = values(each.value.sql_filter_rules)[0].action
}

# Create additional SQL Filter Rules if there are multiple rules per subscription
resource "azurerm_servicebus_subscription_rule" "additional_sql_filters" {
  for_each = var.create_sql_filter_rules ? {
    for rule_key in flatten([
      for topic_key, subscription in var.topic_subscriptions : [
        for rule_name, rule in subscription.sql_filter_rules : {
          key                = "${topic_key}-${rule_name}"
          topic_key         = topic_key
          rule_name         = rule_name
          filter_expression = rule.filter_expression
          action           = rule.action
        }
      ]
    ]) : rule_key.key => rule_key
    if length(var.topic_subscriptions[rule_key.topic_key].sql_filter_rules) > 1
  } : {}

  name            = each.value.rule_name
  subscription_id = azurerm_servicebus_subscription.this[each.value.topic_key].id
  filter_type     = "SqlFilter"
  sql_filter      = each.value.filter_expression
  action          = each.value.action
}
