using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ProjectSetup
    {
        public static IResourceBuilder<ProjectResource> ConfigureUsersApi(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? userDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource>? redis,
            MessageBrokerResources messageBroker)
        {
            var usersProject = builder.AddProject<Projects.TC_CloudGames_Users_Api>("users-api")
                .WithHealthChecks();

            return ConfigureProject(usersProject, null, ProjectType.Users, builder, registry, postgres, userDb, maintenanceDb, redis, messageBroker);
        }

        public static IResourceBuilder<ProjectResource> ConfigureGamesApi(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<ProjectResource>? projectDependency,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? gamesDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource>? redis,
            MessageBrokerResources messageBroker)
        {
            var gamesProject = builder.AddProject<Projects.TC_CloudGames_Games_Api>("games-api")
                .WithHealthChecks();

            return ConfigureProject(gamesProject, projectDependency, ProjectType.Games, builder, registry, postgres, gamesDb, maintenanceDb, redis, messageBroker);
        }

        public static void ConfigurePaymentsApi(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<ProjectResource>? projectDependency,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? paymentsDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource>? redis,
            MessageBrokerResources messageBroker)
        {
            var paymentsProject = builder.AddProject<Projects.TC_CloudGames_Payments_Api>("payments-api")
                .WithHealthChecks();

            ConfigureProject(paymentsProject, projectDependency, ProjectType.Payments, builder, registry, postgres, paymentsDb, maintenanceDb, redis, messageBroker);
        }

        private static IResourceBuilder<ProjectResource> ConfigureProject(
            IResourceBuilder<ProjectResource> project,
            IResourceBuilder<ProjectResource>? projectDependency,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? projectDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource>? redis,
            MessageBrokerResources messageBroker)
        {
            // Add references only for local services (containers)
            if (postgres != null) project = project.WithReference(postgres);
            if (projectDb != null) project = project.WithReference(projectDb);
            if (maintenanceDb != null) project = project.WithReference(maintenanceDb);
            if (redis != null) project = project.WithReference(redis);

            // Add message broker references baseado no tipo
            AddMessageBrokerReferences(project, messageBroker);

            // Wait only for local services
            if (postgres != null) project = project.WaitFor(postgres);
            if (projectDb != null) project = project.WaitFor(projectDb);
            if (maintenanceDb != null) project = project.WaitFor(maintenanceDb);
            if (redis != null) project = project.WaitFor(redis);
            if (projectDependency != null) project = project.WaitFor(projectDependency);

            // Wait for message broker only if it has local resources
            WaitForMessageBrokerIfNeeded(project, messageBroker);

            // Configure environment variables específicas para o ambiente
            ConfigureEnvironmentVariables(project, builder, registry);

            // Configure environment variables específicas para o tipo de projeto
            ConfigureDatabaseEnvironment(project, projectType, builder, registry);
            ConfigureMessageBrokerEnvironment(project, builder, registry, messageBroker.Type, projectType);
            ConfigureCacheEnvironment(project, projectType, builder, registry);
            ConfigureGrafanaCloudEnvironment(project, projectType, builder, registry);

            return project;
        }

        private static IResourceBuilder<ProjectResource> WithHealthChecks(this IResourceBuilder<ProjectResource> project)
        {
            return project
                .WithHttpHealthCheck("/health")
                .WithHttpHealthCheck("/ready")
                .WithHttpHealthCheck("/live");
        }

        private static void AddMessageBrokerReferences(IResourceBuilder<ProjectResource> project, MessageBrokerResources messageBroker)
        {
            switch (messageBroker.Type)
            {
                case MessageBrokerType.RabbitMQ when messageBroker.RabbitMQ != null:
                    project = project.WithReference(messageBroker.RabbitMQ);
                    break;

                case MessageBrokerType.AzureServiceBus when messageBroker.ServiceBus != null:
                    // Para Azure Service Bus, o recurso pode ser um parâmetro ou connection string
                    // Parâmetros não precisam de WithReference, apenas variáveis de ambiente
                    break;
            }
        }

        private static void WaitForMessageBrokerIfNeeded(IResourceBuilder<ProjectResource> project, MessageBrokerResources messageBroker)
        {
            switch (messageBroker.Type)
            {
                case MessageBrokerType.RabbitMQ when messageBroker.RabbitMQ != null:
                    project.WaitFor(messageBroker.RabbitMQ);
                    break;

                case MessageBrokerType.AzureServiceBus:
                    // Azure Service Bus externo não precisa de WaitFor
                    break;
            }
        }

        private static void ConfigureEnvironmentVariables(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var environmentConfig = registry.GetEnvironmentConfig(builder.Configuration);

            project
                .WithEnvironment("ASPNETCORE_ENVIRONMENT", environmentConfig.AspNetCoreEnvironment)
                .WithEnvironment("DOTNET_ENVIRONMENT", environmentConfig.DotNetEnvironment);

            // Add parameter for ASPNETCORE_ENVIRONMENT if available
            if (environmentConfig.AspNetCoreEnvironmentParameter != null)
                project.WithParameterEnv("ASPNETCORE_ENVIRONMENT", environmentConfig.AspNetCoreEnvironmentParameter);
        }

        private static void ConfigureDatabaseEnvironment(
            IResourceBuilder<ProjectResource> project,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var dbConfig = registry.GetDatabaseConfig(builder.Configuration);

            // Apenas setar as configurações específicas por projeto
            var databaseName = GetDatabaseNameForProject(projectType, dbConfig);
            project.WithEnvironment("Database__Name", databaseName);

            // Secrets ainda precisam ser configurados via parameters para segurança
            if (dbConfig.UserParameter != null)
                project.WithParameterEnv("Database__User", dbConfig.UserParameter);

            if (dbConfig.PasswordParameter != null)
                project.WithParameterEnv("Database__Password", dbConfig.PasswordParameter);

            // Nota: Outras configurações (Host, Port, Schema, etc.) são automaticamente 
            // disponibilizadas pelo IConfiguration do Aspire via .env/appsettings
        }

        /// <summary>
        /// Retorna o nome do banco de dados apropriado baseado no tipo de projeto
        /// </summary>
        private static string GetDatabaseNameForProject(ProjectType projectType, DatabaseServiceConfig dbConfig)
        {
            return projectType switch
            {
                ProjectType.Users => dbConfig.UsersDbName,
                ProjectType.Games => dbConfig.GamesDbName,
                ProjectType.Payments => dbConfig.PaymentsDbName,
                _ => throw new ArgumentException($"Tipo de projeto não suportado: {projectType}")
            };
        }

        private static void ConfigureMessageBrokerEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            MessageBrokerType messageBrokerType,
            ProjectType projectType)
        {
            // Apenas setar configurações específicas por tipo de projeto
            switch (messageBrokerType)
            {
                case MessageBrokerType.RabbitMQ:
                    ConfigureRabbitMqEnvironmentSpecific(project, registry, projectType, builder);
                    break;
                case MessageBrokerType.AzureServiceBus:
                    ConfigureAzureServiceBusEnvironmentSpecific(project, registry, projectType, builder);
                    break;
            }

            // Nota: Configurações genéricas (Host, Port, etc.) são automaticamente 
            // disponibilizadas pelo IConfiguration do Aspire via .env/appsettings
        }

        private static void ConfigureRabbitMqEnvironmentSpecific(
            IResourceBuilder<ProjectResource> project,
            ServiceParameterRegistry registry,
            ProjectType projectType,
            IDistributedApplicationBuilder builder)
        {
            var rabbitConfig = registry.GetRabbitMqConfig(builder.Configuration);

            // Apenas configurações específicas por projeto
            var exchange = rabbitConfig.GetExchangeForProject(projectType);
            project.WithEnvironment("RABBITMQ_EXCHANGE", exchange);

            // Secrets ainda precisam ser configurados via parameters
            if (rabbitConfig.UserParameter != null)
                project.WithParameterEnv("RABBITMQ_USERNAME", rabbitConfig.UserParameter);

            if (rabbitConfig.PasswordParameter != null)
                project.WithParameterEnv("RABBITMQ_PASSWORD", rabbitConfig.PasswordParameter);
        }

        private static void ConfigureAzureServiceBusEnvironmentSpecific(
            IResourceBuilder<ProjectResource> project,
            ServiceParameterRegistry registry,
            ProjectType projectType,
            IDistributedApplicationBuilder builder)
        {
            var serviceBusConfig = registry.GetAzureServiceBusConfig(builder.Configuration);

            // Apenas configurações específicas por projeto
            var topicName = serviceBusConfig.GetTopicNameForProject(projectType);
            project.WithEnvironment("AZURE_SERVICEBUS_TOPIC_NAME", topicName);

            // Secrets ainda precisam ser configurados via parameters
            if (serviceBusConfig.ConnectionStringParameter != null)
            {
                project.WithParameterEnv("SERVICEBUS_CONNECTION", serviceBusConfig.ConnectionStringParameter);
                project.WithParameterEnv("AzureWebJobsServiceBus", serviceBusConfig.ConnectionStringParameter);
            }
        }

        private static void ConfigureCacheEnvironment(
            IResourceBuilder<ProjectResource> project,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var cacheConfig = registry.GetCacheConfig(builder.Configuration);

            // Apenas configurações específicas por projeto
            var instanceName = cacheConfig.GetInstanceNameForProject(projectType);
            project.WithEnvironment("CACHE_INSTANCE_NAME", instanceName);

            // Secrets ainda precisam ser configurados via parameters
            if (cacheConfig.PasswordParameter != null)
                project.WithParameterEnv("CACHE_PASSWORD", cacheConfig.PasswordParameter);

            // Nota: Outras configurações (Host, Port, Secure) são automaticamente 
            // disponibilizadas pelo IConfiguration do Aspire via .env/appsettings
        }

        private static void ConfigureGrafanaCloudEnvironment(
            IResourceBuilder<ProjectResource> project,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var grafanaConfig = registry.GetGrafanaCloudConfig(builder.Configuration);

            // Apenas configurações específicas por projeto
            project.WithEnvironment("OTEL_RESOURCE_ATTRIBUTES", GetGrafanaOtelResourceAttributesForProject(projectType, grafanaConfig));

            // Secrets ainda precisam ser configurados via parameters
            if (grafanaConfig.GrafanaLogsApiTokenParameter != null)
                project.WithParameterEnv("GRAFANA_LOGS_API_TOKEN", grafanaConfig.GrafanaLogsApiTokenParameter);

            if (grafanaConfig.GrafanaOtelPrometheusApiTokenParameter != null)
                project.WithParameterEnv("GRAFANA_OTEL_PROMETHEUS_API_TOKEN", grafanaConfig.GrafanaOtelPrometheusApiTokenParameter);

            if (grafanaConfig.OtelExporterOtlpHeadersParameter != null)
                project.WithParameterEnv("OTEL_EXPORTER_OTLP_HEADERS", grafanaConfig.OtelExporterOtlpHeadersParameter);

            // Nota: Outras configurações (Endpoint, Protocol) são automaticamente 
            // disponibilizadas pelo IConfiguration do Aspire via .env/appsettings
        }

        /// <summary>
        /// Configura o projeto Azure Functions com dependências necessárias
        /// </summary>
        public static IResourceBuilder<ProjectResource> ConfigureFunctions(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<IResource> azurite,
            MessageBrokerResources messageBroker,
            Microsoft.Extensions.Logging.ILogger? logger = null)
        {
            logger?.LogInformation("⚡ Configurando Azure Functions");

            var functionsProject = builder.AddProject<Projects.TC_CloudGames_Functions>("functions");

            // Configurar Azurite se disponível
            if (azurite != null)
            {
                functionsProject = functionsProject
                    .WithEnvironment("AzureWebJobsStorage", "UseDevelopmentStorage=true")
                    .WithEnvironment("AZURITE_ACCOUNT_NAME", "devstoreaccount1")
                    .WithEnvironment("AZURITE_BLOB_ENDPOINT", "http://localhost:10000")
                    .WithEnvironment("AZURITE_QUEUE_ENDPOINT", "http://localhost:10001")
                    .WithEnvironment("AZURITE_TABLE_ENDPOINT", "http://localhost:10002")
                    .WaitFor(azurite);
            }

            // Configurar Service Bus se disponível
            if (messageBroker.Type == MessageBrokerType.AzureServiceBus && messageBroker.ServiceBus != null)
            {
                logger?.LogInformation("🚌 Conectando Functions ao Azure Service Bus");
            }

            // Configurar variáveis de ambiente específicas para Functions
            ConfigureFunctionEnvironmentVariables(functionsProject, registry, builder.Configuration, logger);

            return functionsProject;
        }

        /// <summary>
        /// Configura variáveis de ambiente específicas para Azure Functions
        /// </summary>
        private static void ConfigureFunctionEnvironmentVariables(
            IResourceBuilder<ProjectResource> project,
            ServiceParameterRegistry registry,
            ConfigurationManager configuration,
            Microsoft.Extensions.Logging.ILogger? logger = null)
        {
            logger?.LogInformation("🔧 Configurando variáveis de ambiente para Azure Functions");

            // Configurações básicas do Azure Functions
            project.WithEnvironment("FUNCTIONS_WORKER_RUNTIME", "dotnet-isolated");
            project.WithEnvironment("FUNCTIONS_EXTENSION_VERSION", "~4");

            // SendGrid
            var sendGridConfig = registry.GetSendGridConfig();
            if (sendGridConfig.ApiKeyParameter != null)
                project.WithParameterEnv("SENDGRID_API_KEY", sendGridConfig.ApiKeyParameter);
            if (sendGridConfig.EmailNewUserTidParameter != null)
                project.WithParameterEnv("SENDGRID_EMAIL_NEW_USER_TID", sendGridConfig.EmailNewUserTidParameter);
            if (sendGridConfig.EmailPurchaseTidParameter != null)
                project.WithParameterEnv("SENDGRID_EMAIL_PURCHASE_TID", sendGridConfig.EmailPurchaseTidParameter);

            // Service Bus
            var serviceBusConfig = registry.GetAzureServiceBusConfig(configuration);
            if (serviceBusConfig.ConnectionStringParameter != null)
            {
                project.WithParameterEnv("SERVICEBUS_CONNECTION", serviceBusConfig.ConnectionStringParameter);
                project.WithParameterEnv("AzureWebJobsServiceBus", serviceBusConfig.ConnectionStringParameter);
            }
        }

        /// <summary>
        /// Retorna os Resource Attributes do OpenTelemetry específicos para cada projeto
        /// </summary>
        private static string GetGrafanaOtelResourceAttributesForProject(ProjectType projectType, GrafanaCloudServiceConfig grafanaConfig)
        {
            return grafanaConfig.GetOtelResourceAttributesForProject(projectType);
        }
    }
}
