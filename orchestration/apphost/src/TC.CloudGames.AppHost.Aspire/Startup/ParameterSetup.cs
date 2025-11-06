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

            registry.AddParameter(builder, "postgres-user", "Database:User", "postgres");
            registry.AddParameter(builder, "postgres-password", "Database:Password", "postgres", secret: true);
        }

        private static void ConfigureRedisParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("📦 Configurando parâmetros do Redis...");

            registry.AddParameter(builder, "redis-password", "Cache:Password", "Redis@123", secret: true);
        }

        /// <summary>
        /// Configura parâmetros do message broker baseado no tipo configurado (simplificado)
        /// </summary>
        private static void ConfigureMessageBrokerParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            // Determina qual message broker usar - lê diretamente do IConfiguration
            var messageBrokerType = builder.Configuration["MessageBroker:Type"] ??
                                    (builder.Environment.EnvironmentName.ToLowerInvariant() == "development" ? "RabbitMQ" : "AzureServiceBus");

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

            registry.AddParameter(builder, "rabbitmq-user", "RabbitMq:UserName", "guest");
            registry.AddParameter(builder, "rabbitmq-password", "RabbitMq:Password", "guest", secret: true);
        }

        private static void ConfigureAzureServiceBusParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("🚌 Configurando parâmetros do Azure Service Bus...");

            // Apenas connection string é usada como parâmetro secreto
            registry.AddParameter(builder, "servicebus-connection", "AzureServiceBus:ConnectionString", "", secret: true);
        }

        private static void ConfigureGrafanaCloudParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("📊 Configurando parâmetros do Grafana Cloud...");

            registry.AddParameter(builder, "grafana-logs-token", "GrafanaCloud:GrafanaLogsApiToken", "<placeholder for GRAFANA_LOGS_API_TOKEN>", secret: true);
            registry.AddParameter(builder, "grafana-prometheus-token", "GrafanaCloud:GrafanaOtelPrometheusApiToken", "<placeholder for GRAFANA_OTEL_PROMETHEUS_API_TOKEN>", secret: true);
            registry.AddParameter(builder, "otel-exporter-headers", "GrafanaCloud:OtelExporterOtlpHeaders", "<placeholder for OTEL_EXPORTER_OTLP_HEADERS>", secret: true);
        }

        private static void ConfigureApplicationParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("⚙️ Configurando parâmetros da aplicação...");

            // Parâmetros para desenvolvimento local vs. produção
            var environment = builder.Environment.EnvironmentName.ToLowerInvariant();

            registry.AddParameter(builder, "aspnetcore-environment", "ASPNETCORE_ENVIRONMENT", environment);

            // Lê diretamente do IConfiguration
            var messageBrokerType = builder.Configuration["MessageBroker:Type"] ??
            (environment == "development" ? "RabbitMQ" : "AzureServiceBus");
            registry.AddParameter(builder, "message-broker-type", "MessageBroker:Type", messageBrokerType);

            // Configurar parâmetros do SendGrid para Functions
            ConfigureSendGridParameters(builder, registry, logger);
        }

        private static void ConfigureSendGridParameters(IDistributedApplicationBuilder builder, ServiceParameterRegistry registry, ILogger logger)
        {
            logger.LogDebug("📧 Configurando parâmetros do SendGrid...");

            registry.AddParameter(builder, "sendgrid-api-key", "SendGrid:ApiKey", "", secret: true);
            registry.AddParameter(builder, "sendgrid-email-new-user-tid", "SendGrid:EmailNewUserTid", "");
            registry.AddParameter(builder, "sendgrid-email-purchase-tid", "SendGrid:EmailPurchaseTid", "");
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
            string defaultValue,
            bool secret = false)
        {
            // Simplificado: apenas usa IConfiguration (env vars já carregadas)
            string resolvedValue = builder.Configuration[configKey] ?? defaultValue;

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
            var messageBrokerType = ServiceConfigResolver.GetConfigurationValue(
                "MessageBroker:Type",
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
        /// Obtém configuração completa do PostgreSQL (simplificado)
        /// </summary>
        public DatabaseServiceConfig GetDatabaseConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "Database", logger);

            return new DatabaseServiceConfig
            {
                UseExternalService = useExternal,
                // Apenas configurações específicas que podem variar por projeto
                ContainerName = ServiceConfigResolver.GetConfigurationValue("Database:ContainerName", configuration, "TC-CloudGames-Postgres", logger),
                UsersDbName = ServiceConfigResolver.GetConfigurationValue("Database:UsersDbName", configuration, "tc-cloudgames-users-db", logger),
                GamesDbName = ServiceConfigResolver.GetConfigurationValue("Database:GamesDbName", configuration, "tc-cloudgames-games-db", logger),
                PaymentsDbName = ServiceConfigResolver.GetConfigurationValue("Database:PaymentsDbName", configuration, "tc-cloudgames-payments-db", logger),
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
        /// Obtém configuração completa do RabbitMQ (simplificado)
        /// </summary>
        public RabbitMqServiceConfig GetRabbitMqConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "RabbitMq", logger);

            return new RabbitMqServiceConfig
            {
                UseExternalService = useExternal,
                // Apenas configurações específicas
                ContainerName = ServiceConfigResolver.GetConfigurationValue("RabbitMq:ContainerName", configuration, "TC-CloudGames-RabbitMq", logger),
                UsersExchange = ServiceConfigResolver.GetConfigurationValue("RabbitMq:UsersExchange", configuration, "user.events", logger),
                GamesExchange = ServiceConfigResolver.GetConfigurationValue("RabbitMq:GamesExchange", configuration, "game.events", logger),
                PaymentsExchange = ServiceConfigResolver.GetConfigurationValue("RabbitMq:PaymentsExchange", configuration, "payment.events", logger)
            };
        }

        /// <summary>
        /// Obtém configuração completa do Azure Service Bus (simplificado)
        /// </summary>
        public AzureServiceBusServiceConfig GetAzureServiceBusConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "AzureServiceBus", logger);

            return new AzureServiceBusServiceConfig
            {
                UseExternalService = useExternal,
                // Apenas configurações específicas
                ContainerName = ServiceConfigResolver.GetConfigurationValue("AzureServiceBus:ContainerName", configuration, "TC-CloudGames-AzureServiceBus", logger),
                UsersTopicName = ServiceConfigResolver.GetConfigurationValue("AzureServiceBus:UsersTopicName", configuration, "user.events", logger),
                GamesTopicName = ServiceConfigResolver.GetConfigurationValue("AzureServiceBus:GamesTopicName", configuration, "game.events", logger),
                PaymentsTopicName = ServiceConfigResolver.GetConfigurationValue("AzureServiceBus:PaymentsTopicName", configuration, "payment.events", logger)
            };
        }

        /// <summary>
        /// Obtém configuração completa do Grafana Cloud
        /// </summary>
        public GrafanaCloudServiceConfig GetGrafanaCloudConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            return GrafanaCloudServiceConfig.CreateFromConfiguration(configuration, logger);
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
        /// Obtém configuração do ambiente de execução (simplificado)
        /// </summary>
        public EnvironmentServiceConfig GetEnvironmentConfig(ConfigurationManager configuration, ILogger? logger = null)
        {
            return new EnvironmentServiceConfig
            {
                // Lê diretamente do IConfiguration (já carregado via LoadEnvironmentVariables)
                AspNetCoreEnvironment = configuration["ASPNETCORE_ENVIRONMENT"] ?? "Development",
                DotNetEnvironment = configuration["DOTNET_ENVIRONMENT"] ?? "Development",

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
