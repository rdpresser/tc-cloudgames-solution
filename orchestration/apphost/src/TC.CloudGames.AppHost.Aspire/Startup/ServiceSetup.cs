using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ServiceSetup
    {
        public static (IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? userDb,
            IResourceBuilder<PostgresDatabaseResource>? gameDb,
            IResourceBuilder<PostgresDatabaseResource>? paymentDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb) ConfigurePostgres(
                IDistributedApplicationBuilder builder,
                ServiceParameterRegistry registry,
                ILogger? logger = null)
        {
            ValidatePostgresParameters(registry);

            var dbConfig = registry.GetDatabaseConfig(builder.Configuration, logger);

            if (dbConfig.UseExternalService)
            {
                return ConfigureExternalPostgres(dbConfig, logger);
            }
            else
            {
                return ConfigureLocalPostgres(builder, dbConfig, logger);
            }
        }

        public static IResourceBuilder<RedisResource> ConfigureRedis(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            ILogger? logger = null)
        {
            var cacheConfig = registry.GetCacheConfig(builder.Configuration, logger);

            if (cacheConfig.UseExternalService)
            {
                logger?.LogInformation("🌐 Configurando Redis externo");
                // Para serviços externos Redis, criamos um recurso com configuração externa
                return builder.AddRedis(cacheConfig.ContainerName)
                    .WithEndpoint("tcp", endpoint =>
                        endpoint.AllocatedEndpoint = new AllocatedEndpoint(endpoint, cacheConfig.Host, cacheConfig.Port));
            }
            else
            {
                logger?.LogInformation("🐳 Configurando Redis local (Container)");
                return builder.AddRedis(cacheConfig.ContainerName, cacheConfig.Port, cacheConfig.PasswordParameter)
                    .WithImage("redis:latest")
                    .WithContainerName("TC-CloudGames-Redis")
                    .WithDataVolume("tccloudgames_redis_data", isReadOnly: false);
            }
        }

        /// <summary>
        /// Configura o message broker baseado no tipo configurado
        /// </summary>
        public static MessageBrokerResources ConfigureMessageBroker(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            ILogger? logger = null)
        {
            var messageBrokerType = registry.GetConfiguredMessageBrokerType(builder.Configuration, logger);

            logger?.LogInformation("🚌 Configurando Message Broker: {MessageBrokerType}", messageBrokerType);

            return messageBrokerType switch
            {
                MessageBrokerType.RabbitMQ => ConfigureRabbitMQBroker(builder, registry, logger),
                MessageBrokerType.AzureServiceBus => ConfigureAzureServiceBusBroker(builder, registry, logger),
                _ => throw new InvalidOperationException($"Message broker type '{messageBrokerType}' não suportado")
            };
        }

        private static MessageBrokerResources ConfigureRabbitMQBroker(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            ILogger? logger)
        {
            var rabbitConfig = registry.GetRabbitMqConfig(builder.Configuration, logger);

            if (rabbitConfig.UseExternalService)
            {
                logger?.LogInformation("🌐 RabbitMQ externo configurado");
                return new MessageBrokerResources
                {
                    Type = MessageBrokerType.RabbitMQ,
                    RabbitMQ = null, // Não criamos recurso para externo
                    ServiceBus = null
                };
            }
            else
            {
                logger?.LogInformation("🐳 Configurando RabbitMQ local (Container)");
                var rabbitResource = builder.AddRabbitMQ(
                        name: rabbitConfig.ContainerName,
                        userName: rabbitConfig.UserParameter,
                        password: rabbitConfig.PasswordParameter,
                        port: rabbitConfig.Port)
                    .WithContainerName("TC-CloudGames-RabbitMq")
                    .WithDataVolume("tccloudgames_rabbitmq_data", isReadOnly: false)
                    .WithManagementPlugin(15672);

                return new MessageBrokerResources
                {
                    Type = MessageBrokerType.RabbitMQ,
                    RabbitMQ = rabbitResource,
                    ServiceBus = null
                };
            }
        }

        private static MessageBrokerResources ConfigureAzureServiceBusBroker(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            ILogger? logger)
        {
            var serviceBusConfig = registry.GetAzureServiceBusConfig(builder.Configuration, logger);

            if (serviceBusConfig.UseExternalService && !string.IsNullOrEmpty(serviceBusConfig.ConnectionString))
            {
                logger?.LogInformation("🌐 Configurando Azure Service Bus externo");
                var serviceBusResource = builder.AddConnectionString("servicebus-connection", "ServiceBus");

                return new MessageBrokerResources
                {
                    Type = MessageBrokerType.AzureServiceBus,
                    RabbitMQ = null,
                    ServiceBus = serviceBusResource
                };
            }
            else
            {
                logger?.LogWarning("⚠️ Azure Service Bus não configurado adequadamente - Connection String vazia");
                return new MessageBrokerResources
                {
                    Type = MessageBrokerType.AzureServiceBus,
                    RabbitMQ = null,
                    ServiceBus = null
                };
            }
        }

        private static void ValidatePostgresParameters(ServiceParameterRegistry registry)
        {
            if (!registry.Contains("postgres-user") || !registry.Contains("postgres-password"))
                throw new InvalidOperationException("Missing Postgres credentials in ServiceParameterRegistry.");
        }

        private static (IResourceBuilder<PostgresServerResource>?,
            IResourceBuilder<PostgresDatabaseResource>?,
            IResourceBuilder<PostgresDatabaseResource>?,
            IResourceBuilder<PostgresDatabaseResource>?,
            IResourceBuilder<PostgresDatabaseResource>?) ConfigureExternalPostgres(
            DatabaseServiceConfig dbConfig,
            ILogger? logger)
        {
            logger?.LogInformation("🌐 Configurando PostgreSQL externo: {Host} - não criando containers", dbConfig.Host);

            // Para bancos externos, não criamos recursos, apenas retornamos null
            return (null, null, null, null, null);
        }

        private static (IResourceBuilder<PostgresServerResource>,
            IResourceBuilder<PostgresDatabaseResource>,
            IResourceBuilder<PostgresDatabaseResource>,
            IResourceBuilder<PostgresDatabaseResource>,
            IResourceBuilder<PostgresDatabaseResource>) ConfigureLocalPostgres(
            IDistributedApplicationBuilder builder,
            DatabaseServiceConfig dbConfig,
            ILogger? logger)
        {
            logger?.LogInformation("🐳 Configurando PostgreSQL local (Container): {ContainerName}", dbConfig.ContainerName);

            var postgres = builder.AddPostgres(dbConfig.ContainerName)
                .WithImage("postgres:latest")
                .WithContainerName("TC-CloudGames-Db")
                .WithDataVolume("tccloudgames_postgres_data", isReadOnly: false)
                .WithPgAdmin(options => options
                    .WithImage("dpage/pgadmin4:latest")
                    .WithVolume("tccloudgames_pgadmin_data", "/var/lib/pgadmin")
                    .WithContainerName("TC-CloudGames-PgAdmin4"))
                .WithUserName(dbConfig.UserParameter!)
                .WithPassword(dbConfig.PasswordParameter!)
                .WithHostPort(dbConfig.Port);

            var userDb = postgres.AddDatabase("UsersDbConnection", dbConfig.UsersDbName);
            var gameDb = postgres.AddDatabase("GamesDbConnection", dbConfig.GamesDbName);
            var paymentDb = postgres.AddDatabase("PaymentsDbConnection", dbConfig.PaymentsDbName);
            var maintenanceDb = postgres.AddDatabase("MaintenanceDbConnection", dbConfig.MaintenanceDbName);

            return (postgres, userDb, gameDb, paymentDb, maintenanceDb);
        }
    }

    /// <summary>
    /// Container para recursos de message broker
    /// </summary>
    public class MessageBrokerResources
    {
        public MessageBrokerType Type { get; set; }
        public IResourceBuilder<RabbitMQServerResource>? RabbitMQ { get; set; }
        public IResourceBuilder<IResourceWithConnectionString>? ServiceBus { get; set; }
    }
}