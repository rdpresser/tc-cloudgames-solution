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

# Create Topic
resource "azurerm_servicebus_topic" "this" {
  name         = var.topic_name
  namespace_id = azurerm_servicebus_namespace.this.id

  # Correto nas versões novas
  partitioning_enabled  = true
  default_message_ttl   = "P7D" # 7 dias
}

# Create Subscription (fanout style: recebe todas as mensagens)
resource "azurerm_servicebus_subscription" "this" {
  name     = var.subscription_name
  topic_id = azurerm_servicebus_topic.this.id

  max_delivery_count = 10
  lock_duration      = "PT1M"
}
