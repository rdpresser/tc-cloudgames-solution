# =============================================================================
# Elasticsearch on Azure Container Instances
# =============================================================================

# =============================================================================
# Container Group for Elasticsearch
# =============================================================================
resource "azurerm_container_group" "elasticsearch" {
  name                = "${var.name_prefix}-elasticsearch"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Public"
  dns_name_label      = "${var.name_prefix}-elasticsearch"

  # Container for Elasticsearch
  container {
    name   = "elasticsearch"
    image  = "elasticsearch:7.17.9"
    cpu    = var.elasticsearch_cpu
    memory = var.elasticsearch_memory

    ports {
      port     = 9200
      protocol = "TCP"
    }

    ports {
      port     = 9300
      protocol = "TCP"
    }

    environment_variables = {
      "discovery.type"                    = "single-node"
      "xpack.security.enabled"            = "false"
      "xpack.security.http.ssl.enabled"   = "false"
      "xpack.security.transport.ssl.enabled" = "false"
      "ES_JAVA_OPTS"                      = "-Xms${var.elasticsearch_java_heap_size} -Xmx${var.elasticsearch_java_heap_size}"
      "cluster.name"                      = "${var.name_prefix}-cluster"
      "node.name"                         = "${var.name_prefix}-node"
      "bootstrap.memory_lock"             = "true"
      "network.host"                      = "0.0.0.0"
      "http.port"                         = "9200"
      "transport.port"                    = "9300"
    }

    # Volume for persistent storage
    volume {
      name                 = "elasticsearch-data"
      mount_path           = "/usr/share/elasticsearch/data"
      storage_account_name = azurerm_storage_account.elasticsearch.name
      storage_account_key  = azurerm_storage_account.elasticsearch.primary_access_key
      share_name           = azurerm_storage_share.elasticsearch.name
    }

    # Health check
    liveness_probe {
      http_get {
        path = "/_cluster/health"
        port = 9200
      }
      initial_delay_seconds = 60
      period_seconds        = 30
      timeout_seconds       = 10
      failure_threshold     = 3
    }

    readiness_probe {
      http_get {
        path = "/_cluster/health"
        port = 9200
      }
      initial_delay_seconds = 30
      period_seconds        = 10
      timeout_seconds       = 5
      failure_threshold     = 3
    }
  }

  # Container for Kibana (optional)
  dynamic "container" {
    for_each = var.enable_kibana ? [1] : []
    content {
      name   = "kibana"
      image  = "kibana:7.17.9"
      cpu    = var.kibana_cpu
      memory = var.kibana_memory

      ports {
        port     = 5601
        protocol = "TCP"
      }

      environment_variables = {
        "ELASTICSEARCH_HOSTS" = "http://localhost:9200"
        "SERVER_NAME"         = "${var.name_prefix}-kibana"
        "SERVER_HOST"         = "0.0.0.0"
      }

      # Health check for Kibana
      liveness_probe {
        http_get {
          path = "/api/status"
          port = 5601
        }
        initial_delay_seconds = 120
        period_seconds        = 30
        timeout_seconds       = 10
        failure_threshold     = 3
      }

      readiness_probe {
        http_get {
          path = "/api/status"
          port = 5601
        }
        initial_delay_seconds = 60
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 3
      }
    }
  }

  tags = var.tags
}

# =============================================================================
# Storage Account for Elasticsearch data persistence
# =============================================================================
resource "azurerm_storage_account" "elasticsearch" {
  name                     = replace("${var.name_prefix}elasticsearch", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"

  # Enable blob versioning for data protection
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# =============================================================================
# File Share for Elasticsearch data
# =============================================================================
resource "azurerm_storage_share" "elasticsearch" {
  name                 = "elasticsearch-data"
  storage_account_name = azurerm_storage_account.elasticsearch.name
  quota                = var.storage_quota_gb
}

# =============================================================================
# Network Security Group for Elasticsearch
# =============================================================================
resource "azurerm_network_security_group" "elasticsearch" {
  name                = "${var.name_prefix}-elasticsearch-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow HTTP access to Elasticsearch
  security_rule {
    name                       = "AllowElasticsearchHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow transport port for cluster communication
  security_rule {
    name                       = "AllowElasticsearchTransport"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9300"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow Kibana access if enabled
  dynamic "security_rule" {
    for_each = var.enable_kibana ? [1] : []
    content {
      name                       = "AllowKibanaHTTP"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "5601"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  tags = var.tags
}

# =============================================================================
# Application Insights for monitoring (optional)
# =============================================================================
resource "azurerm_application_insights" "elasticsearch" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${var.name_prefix}-elasticsearch-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"

  tags = var.tags
}

# =============================================================================
# Log Analytics Workspace for Elasticsearch logs
# =============================================================================
resource "azurerm_log_analytics_workspace" "elasticsearch" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${var.name_prefix}-elasticsearch-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

