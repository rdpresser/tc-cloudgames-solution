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
# Topics (Condicionais - criados apenas quando create=true)
# =============================================================================
resource "azurerm_servicebus_topic" "this" {
  for_each = {
    for topic in var.topics : topic.name => topic
    if topic.create == true
  }
  
  name         = each.value.name
  namespace_id = azurerm_servicebus_namespace.this.id

  # Correto nas versões novas
  partitioning_enabled  = true
  default_message_ttl   = "P7D" # 7 dias
}

# =============================================================================
# Subscriptions (Para tópicos criados pelo Terraform ou existentes)
# =============================================================================
# Lista de tópicos que devem ser criados via Terraform
locals {
  terraform_created_topics = toset([for t in var.topics : t.name if t.create])
  
  # Determina se há tópicos que precisam ser buscados via data source
  has_existing_topics_needed = length([
    for sub_key, subscription in var.topic_subscriptions : subscription.topic_name
    if !contains(local.terraform_created_topics, subscription.topic_name)
  ]) > 0
  
  # Tópicos únicos que precisam ser buscados via data source (apenas quando necessário)
  existing_topics_needed = local.has_existing_topics_needed ? toset([
    for sub_key, subscription in var.topic_subscriptions : subscription.topic_name
    if !contains(local.terraform_created_topics, subscription.topic_name)
  ]) : toset([])
}

# Data source para obter informações de tópicos existentes (apenas quando há tópicos existentes)
data "azurerm_servicebus_topic" "existing" {
  count = local.has_existing_topics_needed ? length(local.existing_topics_needed) : 0
  
  name         = tolist(local.existing_topics_needed)[count.index]
  namespace_id = azurerm_servicebus_namespace.this.id
}

# Cria um mapa de tópicos existentes para facilitar o lookup
locals {
  existing_topics_map = local.has_existing_topics_needed ? {
    for idx, topic_name in tolist(local.existing_topics_needed) : 
    topic_name => data.azurerm_servicebus_topic.existing[idx].id
  } : {}
}

resource "azurerm_servicebus_subscription" "this" {
  for_each = length(var.topic_subscriptions) > 0 ? var.topic_subscriptions : {}
  name     = each.value.subscription_name
  
  # Use o tópico criado pelo Terraform se existir, senão use o data source do tópico existente
  topic_id = contains(local.terraform_created_topics, each.value.topic_name) ? azurerm_servicebus_topic.this[each.value.topic_name].id : local.existing_topics_map[each.value.topic_name]

  max_delivery_count = 10
  lock_duration      = "PT1M"
  
  # Dependência explícita para garantir que os tópicos sejam criados primeiro
  depends_on = [azurerm_servicebus_topic.this]
}

# =============================================================================
# SQL Filter Rules (Opcionais - podem ser criadas via código C#)
# =============================================================================
resource "azurerm_servicebus_subscription_rule" "sql_filter" {
  for_each = var.create_sql_filter_rules ? {
    for rule_key in flatten([
      for sub_key, subscription in var.topic_subscriptions : [
        for rule_name, rule in subscription.sql_filter_rules : {
          key                = "${sub_key}-${rule_name}"
          sub_key           = sub_key
          rule_name         = rule_name
          filter_expression = rule.filter_expression
          action           = rule.action
          custom_rule_name = rule.rule_name
        }
      ]
    ]) : rule_key.key => rule_key
    if length(var.topic_subscriptions[rule_key.sub_key].sql_filter_rules) > 0
  } : {}

  name            = each.value.custom_rule_name
  subscription_id = azurerm_servicebus_subscription.this[each.value.sub_key].id
  filter_type     = "SqlFilter"
  sql_filter      = each.value.filter_expression
  action          = each.value.action
}
