using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ParameterSetup
    {
        public static ServiceParameterRegistry ConfigureParameters(IDistributedApplicationBuilder builder, ILogger logger)
        {
            logger.LogInformation("🔧 Configurando parâmetros do Aspire...");

            var registry = new ServiceParameterRegistry();

            // Configurar parâmetros básicos
            ConfigurePostgresParameters(builder, registry, logger);
            ConfigureRedisParameters(builder, registry, logger);
            ConfigureApplicationParameters(builder, registry, logger);

            // Configurar message broker baseado no tipo
            ConfigureMessageBrokerParameters(builder, registry, logger);

            // Configurar Grafana Cloud parameters
            ConfigureGrafanaCloudParameters(builder, registry, logger);

            logger.LogInformation("✅ Configuração de parâmetros concluída");
            registry.LogAll(builder.Configuration, logger);

            return registry;
        }

        private static void ConfigurePostgresParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("🗄️ Configurando parâmetros do PostgreSQL...");

            registry.AddParameter(builder, "postgres-user", "Database:User", "DB_USER", "postgres");
            registry.AddParameter(builder, "postgres-password", "Database:Password", "DB_PASSWORD", "postgres", secret: true);
        }

        private static void ConfigureRedisParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("📦 Configurando parâmetros do Redis...");

            registry.AddParameter(builder, "redis-password", "Cache:Password", "CACHE_PASSWORD", "Redis@123", secret: true);
        }

        /// <summary>
        /// Configura parâmetros do message broker baseado no tipo configurado
        /// </summary>
        private static void ConfigureMessageBrokerParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            // Determina qual message broker usar
            var messageBrokerType = ServiceConfigResolver.GetResolvedValue(
                "MessageBroker:Type",
                "MESSAGE_BROKER_TYPE",
                builder.Configuration,
                builder.Environment.EnvironmentName.ToLowerInvariant() == "development" ? "RabbitMQ" : "AzureServiceBus",
                logger);

            logger.LogInformation("🚌 Message Broker Type: {MessageBrokerType}", messageBrokerType);

            switch (messageBrokerType.ToUpperInvariant())
            {
                case "RABBITMQ":
                    ConfigureRabbitMqParameters(builder, registry, logger);
                    break;

                case "AZURESERVICEBUS":
                    ConfigureAzureServiceBusParameters(builder, registry, logger);
                    break;

                default:
                    logger.LogWarning("⚠️ Message broker type '{MessageBrokerType}' não reconhecido. Usando RabbitMQ como fallback.", messageBrokerType);
                    ConfigureRabbitMqParameters(builder, registry, logger);
                    break;
            }
        }

        private static void ConfigureRabbitMqParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("🐰 Configurando parâmetros do RabbitMQ...");

            registry.AddParameter(builder, "rabbitmq-user", "RabbitMq:UserName", "RABBITMQ_USERNAME", "guest");
            registry.AddParameter(builder, "rabbitmq-password", "RabbitMq:Password", "RABBITMQ_PASSWORD", "guest", secret: true);
        }

        private static void ConfigureAzureServiceBusParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("🚌 Configurando parâmetros do Azure Service Bus...");

            // Apenas connection string é usada como parâmetro secreto
            registry.AddParameter(builder, "servicebus-connection", "AzureServiceBus:ConnectionString", "AZURE_SERVICEBUS_CONNECTIONSTRING", "", secret: true);
        }

        private static void ConfigureGrafanaCloudParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("📊 Configurando parâmetros do Grafana Cloud...");

            registry.AddParameter(builder, "grafana-logs-token", "GrafanaCloud:GrafanaLogsApiToken", "GRAFANA_LOGS_API_TOKEN", "<placeholder for GRAFANA_LOGS_API_TOKEN>", secret: true);
            registry.AddParameter(builder, "grafana-prometheus-token", "GrafanaCloud:GrafanaOtelPrometheusApiToken", "GRAFANA_OTEL_PROMETHEUS_API_TOKEN", "<placeholder for GRAFANA_OTEL_PROMETHEUS_API_TOKEN>", secret: true);
            registry.AddParameter(builder, "otel-exporter-headers", "GrafanaCloud:OtelExporterOtlpHeaders", "OTEL_EXPORTER_OTLP_HEADERS", "<placeholder for OTEL_EXPORTER_OTLP_HEADERS>", secret: true);
        }

        private static void ConfigureApplicationParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("⚙️ Configurando parâmetros da aplicação...");

            // Parâmetros para desenvolvimento local vs. produção
            var environment = builder.Environment.EnvironmentName.ToLowerInvariant();

            registry.AddParameter(builder, "aspnetcore-environment", "ASPNETCORE_ENVIRONMENT", "ASPNETCORE_ENVIRONMENT", environment);
            registry.AddParameter(builder, "message-broker-type", "MessageBroker:Type", "MESSAGE_BROKER_TYPE",
                environment == "development" ? "RabbitMQ" : "AzureServiceBus");

            // Configurar parâmetros do SendGrid para Functions
            ConfigureSendGridParameters(builder, registry, logger);
        }

        private static void ConfigureSendGridParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("📧 Configurando parâmetros do SendGrid...");

            registry.AddParameter(builder, "sendgrid-api-key", "SendGrid:ApiKey", "SENDGRID_API_KEY", "", secret: true);
            registry.AddParameter(builder, "sendgrid-email-new-user-tid", "SendGrid:EmailNewUserTid", "SENDGRID_EMAIL_NEW_USER_TID", "");
            registry.AddParameter(builder, "sendgrid-email-purchase-tid", "SendGrid:EmailPurchaseTid", "SENDGRID_EMAIL_PURCHASE_TID", "");
        }
    }

    /// <summary>
    /// Registry simplificado para parâmetros de serviços
    /// </summary>
    public class ServiceParameterRegistry
    {
        private readonly Dictionary<string, IResourceBuilder<ParameterResource>> _parameters = new();

        public IResourceBuilder<ParameterResource> AddParameter(
            IDistributedApplicationBuilder builder,
            string parameterName,
            string configKey,
            string envVarName,
            string defaultValue,
            bool secret = false)
        {
            string resolvedValue = ServiceConfigResolver.GetResolvedValue(configKey, envVarName, builder.Configuration, defaultValue);

            var resource = builder.AddParameter(parameterName,
                valueGetter: () => resolvedValue,
                publishValueAsDefault: !secret,
                secret: secret);

            _parameters[parameterName] = resource;
            return resource;
        }

        public IResourceBuilder<ParameterResource> this[string parameterName]
        {
            get
            {
                return _parameters.TryGetValue(parameterName, out var param)
                    ? param
                    : throw new KeyNotFoundException($"Parâmetro '{parameterName}' não encontrado.");
            }
        }

        public bool Contains(string parameterName) => _parameters.ContainsKey(parameterName);

        /// <summary>
        /// Determina qual message broker está configurado
        /// </summary>
        public MessageBrokerType GetConfiguredMessageBrokerType(ConfigurationManager configuration, ILogger? logger = null)
        {
            var messageBrokerType = ServiceConfigResolver.GetResolvedValue(
                "MessageBroker:Type",
                "MESSAGE_BROKER_TYPE",
                configuration,
                "RabbitMQ",
                logger);

            return messageBrokerType.ToUpperInvariant() switch
            {
                "RABBITMQ" => MessageBrokerType.RabbitMQ,
                "AZURESERVICEBUS" => MessageBrokerType.AzureServiceBus,
                _ => MessageBrokerType.RabbitMQ // fallback
            };
        }

        /// <summary>
        /// Obtém configuração completa do PostgreSQL
        /// </summary>
        public DatabaseServiceConfig GetDatabaseConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "Database", logger);

            return new DatabaseServiceConfig
            {
                UseExternalService = useExternal,
                ContainerName = ServiceConfigResolver.GetResolvedValue("Database:ContainerName", "DB_CONTAINER_NAME", configuration, "TC-CloudGames-Postgres", logger),
                Host = ServiceConfigResolver.GetResolvedValue("Database:Host", "DB_HOST", configuration, useExternal ? "" : "localhost", logger),
                Port = int.Parse(ServiceConfigResolver.GetResolvedValue("Database:Port", "DB_PORT", configuration, "5432", logger)),
                UsersDbName = ServiceConfigResolver.GetResolvedValue("Database:UsersDbName", "DB_USERS_NAME", configuration, "tc-cloudgames-users-db", logger),
                GamesDbName = ServiceConfigResolver.GetResolvedValue("Database:GamesDbName", "DB_GAMES_NAME", configuration, "tc-cloudgames-games-db", logger),
                PaymentsDbName = ServiceConfigResolver.GetResolvedValue("Database:PaymentsDbName", "DB_PAYMENTS_NAME", configuration, "tc-cloudgames-payments-db", logger),
                MaintenanceDbName = ServiceConfigResolver.GetResolvedValue("Database:MaintenanceDbName", "DB_MAINTENANCE_NAME", configuration, "postgres", logger),
                User = ServiceConfigResolver.GetResolvedValue("Database:User", "DB_USER", configuration, "postgres", logger),
                Password = ServiceConfigResolver.GetResolvedValue("Database:Password", "DB_PASSWORD", configuration, "postgres", logger),
                Schema = ServiceConfigResolver.GetResolvedValue("Database:Schema", "DB_SCHEMA", configuration, "public", logger),
                ConnectionTimeout = int.Parse(ServiceConfigResolver.GetResolvedValue("Database:ConnectionTimeout", "DB_CONNECTION_TIMEOUT", configuration, "30", logger)),

                // Aspire Parameters
                UserParameter = Contains("postgres-user") ? this["postgres-user"] : null,
                PasswordParameter = Contains("postgres-password") ? this["postgres-password"] : null,
            };
        }

        /// <summary>
        /// Obtém configuração completa do Redis
        /// </summary>
        public CacheServiceConfig GetCacheConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var passwordParameter = Contains("redis-password") ? this["redis-password"] : null;
            return CacheServiceConfig.CreateFromConfiguration(configuration, passwordParameter, logger);
        }

        /// <summary>
        /// Obtém configuração completa do RabbitMQ
        /// </summary>
        public RabbitMqServiceConfig GetRabbitMqConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "RabbitMq", logger);

            return new RabbitMqServiceConfig
            {
                UseExternalService = useExternal,
                ContainerName = ServiceConfigResolver.GetResolvedValue("RabbitMq:ContainerName", "RABBITMQ_CONTAINER_NAME", configuration, "TC-CloudGames-RabbitMq", logger),
                Host = ServiceConfigResolver.GetResolvedValue("RabbitMq:Host", "RABBITMQ_HOST", configuration, useExternal ? "" : "localhost", logger),
                Port = int.Parse(ServiceConfigResolver.GetResolvedValue("RabbitMq:Port", "RABBITMQ_PORT", configuration, "5672", logger)),
                VirtualHost = ServiceConfigResolver.GetResolvedValue("RabbitMq:VirtualHost", "RABBITMQ_VHOST", configuration, "/", logger),
                UserName = ServiceConfigResolver.GetResolvedValue("RabbitMq:UserName", "RABBITMQ_USERNAME", configuration, "guest", logger),
                Password = ServiceConfigResolver.GetResolvedValue("RabbitMq:Password", "RABBITMQ_PASSWORD", configuration, "guest", logger),
                UsersExchange = ServiceConfigResolver.GetResolvedValue("RabbitMq:UsersExchange", "RABBITMQ_USERS_EXCHANGE", configuration, "user.events", logger),
                GamesExchange = ServiceConfigResolver.GetResolvedValue("RabbitMq:GamesExchange", "RABBITMQ_GAMES_EXCHANGE", configuration, "game.events", logger),
                PaymentsExchange = ServiceConfigResolver.GetResolvedValue("RabbitMq:PaymentsExchange", "RABBITMQ_PAYMENTS_EXCHANGE", configuration, "payment.events", logger),
                AutoProvision = bool.Parse(ServiceConfigResolver.GetResolvedValue("RabbitMq:AutoProvision", "RABBITMQ_AUTO_PROVISION", configuration, "true", logger)),
                Durable = bool.Parse(ServiceConfigResolver.GetResolvedValue("RabbitMq:Durable", "RABBITMQ_DURABLE", configuration, "true", logger)),
                UseQuorumQueues = bool.Parse(ServiceConfigResolver.GetResolvedValue("RabbitMq:UseQuorumQueues", "RABBITMQ_USE_QUORUM_QUEUES", configuration, "false", logger)),
                AutoPurgeOnStartup = bool.Parse(ServiceConfigResolver.GetResolvedValue("RabbitMq:AutoPurgeOnStartup", "RABBITMQ_AUTO_PURGE_ON_STARTUP", configuration, "false", logger)),

                // Aspire Parameters
                UserParameter = Contains("rabbitmq-user") ? this["rabbitmq-user"] : null,
                PasswordParameter = Contains("rabbitmq-password") ? this["rabbitmq-password"] : null
            };
        }

        /// <summary>
        /// Obtém configuração completa do Azure Service Bus
        /// </summary>
        public AzureServiceBusServiceConfig GetAzureServiceBusConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "AzureServiceBus", logger);

            return new AzureServiceBusServiceConfig
            {
                UseExternalService = useExternal,
                ContainerName = ServiceConfigResolver.GetResolvedValue("AzureServiceBus:ContainerName", "AZURE_SERVICEBUS_CONTAINER_NAME", configuration, "TC-CloudGames-AzureServiceBus", logger),
                ConnectionString = ServiceConfigResolver.GetResolvedValue("AzureServiceBus:ConnectionString", "AZURE_SERVICEBUS_CONNECTIONSTRING", configuration, "", logger),
                UsersTopicName = ServiceConfigResolver.GetResolvedValue("AzureServiceBus:UsersTopicName", "AZURE_SERVICEBUS_USERS_TOPIC", configuration, "user.events", logger),
                GamesTopicName = ServiceConfigResolver.GetResolvedValue("AzureServiceBus:GamesTopicName", "AZURE_SERVICEBUS_GAMES_TOPIC", configuration, "game.events", logger),
                PaymentsTopicName = ServiceConfigResolver.GetResolvedValue("AzureServiceBus:PaymentsTopicName", "AZURE_SERVICEBUS_PAYMENTS_TOPIC", configuration, "payment.events", logger),
                AutoProvision = bool.Parse(ServiceConfigResolver.GetResolvedValue("AzureServiceBus:AutoProvision", "AZURE_SERVICEBUS_AUTO_PROVISION", configuration, "true", logger)),
                MaxDeliveryCount = int.Parse(ServiceConfigResolver.GetResolvedValue("AzureServiceBus:MaxDeliveryCount", "AZURE_SERVICEBUS_MAX_DELIVERY_COUNT", configuration, "10", logger)),
                EnableDeadLettering = bool.Parse(ServiceConfigResolver.GetResolvedValue("AzureServiceBus:EnableDeadLettering", "AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING", configuration, "true", logger)),
                AutoPurgeOnStartup = bool.Parse(ServiceConfigResolver.GetResolvedValue("AzureServiceBus:AutoPurgeOnStartup", "AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP", configuration, "false", logger)),
                UseControlQueues = bool.Parse(ServiceConfigResolver.GetResolvedValue("AzureServiceBus:UseControlQueues", "AZURE_SERVICEBUS_USE_CONTROL_QUEUES", configuration, "true", logger)),

                // Aspire Parameters
                ConnectionStringParameter = Contains("servicebus-connection") ? this["servicebus-connection"] : null
            };
        }

        /// <summary>
        /// Obtém configuração completa do Grafana Cloud
        /// </summary>
        public GrafanaCloudServiceConfig GetGrafanaCloudConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var grafanaLogsTokenParameter = Contains("grafana-logs-token") ? this["grafana-logs-token"] : null;
            var grafanaPrometheusTokenParameter = Contains("grafana-prometheus-token") ? this["grafana-prometheus-token"] : null;
            var otelExporterHeadersParameter = Contains("otel-exporter-headers") ? this["otel-exporter-headers"] : null;

            return GrafanaCloudServiceConfig.CreateFromConfiguration(configuration, grafanaLogsTokenParameter, grafanaPrometheusTokenParameter, otelExporterHeadersParameter, logger);
        }

        /// <summary>
        /// Obtém configuração do SendGrid para Functions
        /// </summary>
        public SendGridServiceConfig GetSendGridConfig()
        {
            return new SendGridServiceConfig
            {
                ApiKeyParameter = Contains("sendgrid-api-key") ? this["sendgrid-api-key"] : null,
                EmailNewUserTidParameter = Contains("sendgrid-email-new-user-tid") ? this["sendgrid-email-new-user-tid"] : null,
                EmailPurchaseTidParameter = Contains("sendgrid-email-purchase-tid") ? this["sendgrid-email-purchase-tid"] : null
            };
        }

        /// <summary>
        /// Obtém configuração do ambiente de execução
        /// </summary>
        public EnvironmentServiceConfig GetEnvironmentConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            return new EnvironmentServiceConfig
            {
                AspNetCoreEnvironment = ServiceConfigResolver.GetResolvedValue("ASPNETCORE_ENVIRONMENT", "ASPNETCORE_ENVIRONMENT", configuration, "Development", logger),
                DotNetEnvironment = ServiceConfigResolver.GetResolvedValue("DOTNET_ENVIRONMENT", "DOTNET_ENVIRONMENT", configuration, "Development", logger),
                
                // Aspire Parameters
                AspNetCoreEnvironmentParameter = Contains("aspnetcore-environment") ? this["aspnetcore-environment"] : null
            };
        }

        public void LogAll(ConfigurationManager config, ILogger logger)
        {
            logger.LogInformation("📋 Resumo da Resolução de Parâmetros:");
            foreach (var kvp in _parameters)
            {
                logger.LogInformation("🔎 {ParameterName} configurado", kvp.Key);
            }
        }
    }

    /// <summary>
    /// Configuração para SendGrid
    /// </summary>
    public class SendGridServiceConfig
    {
        public IResourceBuilder<ParameterResource>? ApiKeyParameter { get; set; }
        public IResourceBuilder<ParameterResource>? EmailNewUserTidParameter { get; set; }
        public IResourceBuilder<ParameterResource>? EmailPurchaseTidParameter { get; set; }
    }

    /// <summary>
    /// Configuração para ambiente de execução
    /// </summary>
    public class EnvironmentServiceConfig
    {
        public required string AspNetCoreEnvironment { get; set; }
        public required string DotNetEnvironment { get; set; }
        
        // Recursos Aspire para parâmetros
        public IResourceBuilder<ParameterResource>? AspNetCoreEnvironmentParameter { get; set; }
    }

    /// <summary>
    /// Tipos de message broker suportados
    /// </summary>
    public enum MessageBrokerType
    {
        RabbitMQ,
        AzureServiceBus
    }
}
