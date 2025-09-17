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

# Create Topics
resource "azurerm_servicebus_topic" "this" {
  for_each     = toset(var.topics)
  name         = each.value
  namespace_id = azurerm_servicebus_namespace.this.id

  # Correto nas versões novas
  partitioning_enabled  = true
  default_message_ttl   = "P7D" # 7 dias
}

# Create Subscriptions (fanout style: recebe todas as mensagens)
resource "azurerm_servicebus_subscription" "this" {
  for_each = var.topic_subscriptions
  name     = each.value
  topic_id = azurerm_servicebus_topic.this[each.key].id

  max_delivery_count = 10
  lock_duration      = "PT1M"
}
