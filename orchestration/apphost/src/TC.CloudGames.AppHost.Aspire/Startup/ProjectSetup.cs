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
            IResourceBuilder<ElasticsearchResource>? elastic,
            MessageBrokerResources messageBroker)
        {
            var usersProject = builder.AddProject<Projects.TC_CloudGames_Users_Api>("users-api")
                .WithHealthChecks();

            return ConfigureProject(usersProject, null, ProjectType.Users, builder, registry, postgres, userDb, maintenanceDb, redis, elastic, messageBroker);
        }

        public static IResourceBuilder<ProjectResource> ConfigureGamesApi(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<ProjectResource>? projectDependency,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? gamesDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource>? redis,
            IResourceBuilder<ElasticsearchResource>? elastic,
            MessageBrokerResources messageBroker)
        {
            var gamesProject = builder.AddProject<Projects.TC_CloudGames_Games_Api>("games-api")
                .WithHealthChecks();

            return ConfigureProject(gamesProject, projectDependency, ProjectType.Games, builder, registry, postgres, gamesDb, maintenanceDb, redis, elastic, messageBroker);
        }

        public static IResourceBuilder<ProjectResource> ConfigurePaymentsApi(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<ProjectResource>? projectDependency,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? paymentsDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource>? redis,
            IResourceBuilder<ElasticsearchResource>? elastic,
            MessageBrokerResources messageBroker)
        {
            var paymentsProject = builder.AddProject<Projects.TC_CloudGames_Payments_Api>("payments-api")
                .WithHealthChecks();

            return ConfigureProject(paymentsProject, projectDependency, ProjectType.Payments, builder, registry, postgres, paymentsDb, maintenanceDb, redis, elastic, messageBroker);
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
            IResourceBuilder<ElasticsearchResource>? elastic,
            MessageBrokerResources messageBroker)
        {
            // Add references only for local services (containers)
            if (postgres != null) project = project.WithReference(postgres);
            if (projectDb != null) project = project.WithReference(projectDb);
            if (maintenanceDb != null) project = project.WithReference(maintenanceDb);
            if (redis != null) project = project.WithReference(redis);
            if (elastic != null) project = project.WithReference(elastic);

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

            // Configure environment variables específicas para o tipo de projeto
            ConfigureDatabaseEnvironment(project, projectType, builder, registry);
            ConfigureMessageBrokerEnvironment(project, builder, registry, messageBroker.Type, projectType);
            ConfigureCacheEnvironment(project, projectType, builder, registry);
            ConfigureElasticsearchEnvironment(project, projectType, builder, registry);

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

        private static void ConfigureDatabaseEnvironment(
            IResourceBuilder<ProjectResource> project,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var dbConfig = registry.GetDatabaseConfig(builder.Configuration);

            // Seleciona o nome do banco baseado no tipo de projeto
            var databaseName = GetDatabaseNameForProject(projectType, dbConfig);

            project
                .WithEnvironment("DB_HOST", dbConfig.Host)
                .WithEnvironment("DB_PORT", dbConfig.Port.ToString())
                .WithEnvironment("DB_NAME", databaseName)
                .WithEnvironment("DB_MAINTENANCE_NAME", dbConfig.MaintenanceDbName)
                .WithEnvironment("DB_SCHEMA", dbConfig.Schema)
                .WithEnvironment("DB_CONNECTION_TIMEOUT", dbConfig.ConnectionTimeout.ToString());

            // Add parameters for secrets
            if (dbConfig.UserParameter != null)
                project.WithParameterEnv("DB_USER", dbConfig.UserParameter);

            if (dbConfig.PasswordParameter != null)
                project.WithParameterEnv("DB_PASSWORD", dbConfig.PasswordParameter);
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
            project.WithEnvironment("MESSAGE_BROKER_TYPE", messageBrokerType.ToString());

            switch (messageBrokerType)
            {
                case MessageBrokerType.RabbitMQ:
                    ConfigureRabbitMqEnvironment(project, builder, registry, projectType);
                    break;
                case MessageBrokerType.AzureServiceBus:
                    ConfigureAzureServiceBusEnvironment(project, builder, registry, projectType);
                    break;
            }
        }

        private static void ConfigureRabbitMqEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            ProjectType projectType)
        {
            var rabbitConfig = registry.GetRabbitMqConfig(builder.Configuration);
            var exchange = rabbitConfig.GetExchangeForProject(projectType);

            project
                .WithEnvironment("RABBITMQ_HOST", rabbitConfig.Host)
                .WithEnvironment("RABBITMQ_PORT", rabbitConfig.Port.ToString())
                .WithEnvironment("RABBITMQ_VHOST", rabbitConfig.VirtualHost)
                .WithEnvironment("RABBITMQ_EXCHANGE", exchange)
                .WithEnvironment("RABBITMQ_AUTO_PROVISION", rabbitConfig.AutoProvision.ToString())
                .WithEnvironment("RABBITMQ_DURABLE", rabbitConfig.Durable.ToString())
                .WithEnvironment("RABBITMQ_USE_QUORUM_QUEUES", rabbitConfig.UseQuorumQueues.ToString())
                .WithEnvironment("RABBITMQ_AUTO_PURGE_ON_STARTUP", rabbitConfig.AutoPurgeOnStartup.ToString());

            // Add parameters for secrets
            if (rabbitConfig.UserParameter != null)
                project.WithParameterEnv("RABBITMQ_USERNAME", rabbitConfig.UserParameter);

            if (rabbitConfig.PasswordParameter != null)
                project.WithParameterEnv("RABBITMQ_PASSWORD", rabbitConfig.PasswordParameter);
        }

        private static void ConfigureAzureServiceBusEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            ProjectType projectType)
        {
            var serviceBusConfig = registry.GetAzureServiceBusConfig(builder.Configuration);
            var topicName = serviceBusConfig.GetTopicNameForProject(projectType);

            project
                .WithEnvironment("AZURE_SERVICEBUS_TOPIC_NAME", topicName)
                .WithEnvironment("AZURE_SERVICEBUS_AUTO_PROVISION", serviceBusConfig.AutoProvision.ToString())
                .WithEnvironment("AZURE_SERVICEBUS_MAX_DELIVERY_COUNT", serviceBusConfig.MaxDeliveryCount.ToString())
                .WithEnvironment("AZURE_SERVICEBUS_ENABLE_DEAD_LETTERING", serviceBusConfig.EnableDeadLettering.ToString())
                .WithEnvironment("AZURE_SERVICEBUS_AUTO_PURGE_ON_STARTUP", serviceBusConfig.AutoPurgeOnStartup.ToString())
                .WithEnvironment("AZURE_SERVICEBUS_USE_CONTROL_QUEUES", serviceBusConfig.UseControlQueues.ToString());

            // Add parameters for secrets
            if (serviceBusConfig.ConnectionStringParameter != null)
                project.WithParameterEnv("AZURE_SERVICEBUS_CONNECTIONSTRING", serviceBusConfig.ConnectionStringParameter);
        }

        private static void ConfigureCacheEnvironment(
            IResourceBuilder<ProjectResource> project,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var cacheConfig = registry.GetCacheConfig(builder.Configuration);

            // Seleciona o nome da instância baseado no tipo de projeto
            var instanceName = cacheConfig.GetInstanceNameForProject(projectType);

            project
                .WithEnvironment("CACHE_HOST", cacheConfig.Host)
                .WithEnvironment("CACHE_PORT", cacheConfig.Port.ToString())
                .WithEnvironment("CACHE_INSTANCE_NAME", instanceName)
                .WithEnvironment("CACHE_SECURE", cacheConfig.Secure.ToString());

            // Add parameters for secrets
            if (cacheConfig.PasswordParameter != null)
                project.WithParameterEnv("CACHE_PASSWORD", cacheConfig.PasswordParameter);
        }

        private static void ConfigureElasticsearchEnvironment(
            IResourceBuilder<ProjectResource> project,
            ProjectType projectType,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var elasticConfig = registry.GetElasticConfig(builder.Configuration);

            project
                .WithEnvironment("ELASTICSEARCH_HOST", elasticConfig.Host)
                .WithEnvironment("ELASTICSEARCH_PORT", elasticConfig.Port)
                .WithEnvironment("ELASTICSEARCH_INDEXPREFIX", elasticConfig.IndexName);

            // Add parameters for secrets
            if (!string.IsNullOrEmpty(elasticConfig.Username))
                project.WithEnvironment("ELASTICSEARCH_USERNAME", elasticConfig.Username);
            
            if (!string.IsNullOrEmpty(elasticConfig.Password))
                project.WithEnvironment("ELASTICSEARCH_PASSWORD", elasticConfig.Password);
        }
    }
}
