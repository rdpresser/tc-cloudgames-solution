using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ProjectSetup
    {
        public static void ConfigureUsersApi(
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            IResourceBuilder<PostgresServerResource>? postgres,
            IResourceBuilder<PostgresDatabaseResource>? userDb,
            IResourceBuilder<PostgresDatabaseResource>? maintenanceDb,
            IResourceBuilder<RedisResource> redis,
            MessageBrokerResources messageBroker)
        {
            var project = builder.AddProject<Projects.TC_CloudGames_Users_Api>("users-api")
                .WithHealthChecks();

            // Add references only for local services (containers)
            if (postgres != null) project = project.WithReference(postgres);
            if (userDb != null) project = project.WithReference(userDb);
            if (maintenanceDb != null) project = project.WithReference(maintenanceDb);
            
            project = project.WithReference(redis);
            
            // Add message broker references baseado no tipo
            AddMessageBrokerReferences(project, messageBroker);

            // Wait only for local services
            if (postgres != null) project = project.WaitFor(postgres);
            if (userDb != null) project = project.WaitFor(userDb);
            if (maintenanceDb != null) project = project.WaitFor(maintenanceDb);
            
            project = project.WaitFor(redis);
            
            // Wait for message broker only if it has local resources
            WaitForMessageBrokerIfNeeded(project, messageBroker);

            // Configure environment variables uniformly
            ConfigureDatabaseEnvironment(project, builder, registry);
            ConfigureMessageBrokerEnvironment(project, builder, registry, messageBroker.Type);
            ConfigureCacheEnvironment(project, builder, registry);
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
                    project = project.WithReference(messageBroker.ServiceBus);
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
                
                case MessageBrokerType.AzureServiceBus when messageBroker.ServiceBus != null:
                    project.WaitFor(messageBroker.ServiceBus);
                    break;
            }
        }

        private static void ConfigureDatabaseEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var dbConfig = registry.GetDatabaseConfig(builder.Configuration);
            
            project
                .WithEnvironment("DB_HOST", dbConfig.Host)
                .WithEnvironment("DB_PORT", dbConfig.Port.ToString())
                .WithEnvironment("DB_USERS_NAME", dbConfig.UsersDbName)
                .WithEnvironment("DB_GAMES_NAME", dbConfig.GamesDbName)
                .WithEnvironment("DB_PAYMENTS_NAME", dbConfig.PaymentsDbName)
                .WithEnvironment("DB_MAINTENANCE_NAME", dbConfig.MaintenanceDbName)
                .WithEnvironment("DB_SCHEMA", dbConfig.Schema)
                .WithEnvironment("DB_CONNECTION_TIMEOUT", dbConfig.ConnectionTimeout.ToString());

            // Add parameters for secrets
            if (dbConfig.UserParameter != null)
                project.WithParameterEnv("DB_USER", dbConfig.UserParameter);
            
            if (dbConfig.PasswordParameter != null)
                project.WithParameterEnv("DB_PASSWORD", dbConfig.PasswordParameter);
        }

        private static void ConfigureMessageBrokerEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry,
            MessageBrokerType messageBrokerType)
        {
            // Set the message broker type
            project.WithEnvironment("MESSAGE_BROKER_TYPE", messageBrokerType.ToString());

            switch (messageBrokerType)
            {
                case MessageBrokerType.RabbitMQ:
                    ConfigureRabbitMqEnvironment(project, builder, registry);
                    break;
                
                case MessageBrokerType.AzureServiceBus:
                    ConfigureAzureServiceBusEnvironment(project, builder, registry);
                    break;
            }
        }

        private static void ConfigureRabbitMqEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var rabbitConfig = registry.GetRabbitMqConfig(builder.Configuration);
            
            project
                .WithEnvironment("RABBITMQ_HOST", rabbitConfig.Host)
                .WithEnvironment("RABBITMQ_PORT", rabbitConfig.Port.ToString())
                .WithEnvironment("RABBITMQ_VHOST", rabbitConfig.VirtualHost)
                .WithEnvironment("RABBITMQ_EXCHANGE", rabbitConfig.Exchange)
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
            ServiceParameterRegistry registry)
        {
            var serviceBusConfig = registry.GetAzureServiceBusConfig(builder.Configuration);
            
            project
                .WithEnvironment("AZURE_SERVICEBUS_TOPIC_NAME", serviceBusConfig.TopicName)
                .WithEnvironment("AZURE_SERVICEBUS_SUBSCRIPTION_NAME", serviceBusConfig.SubscriptionName)
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
            IDistributedApplicationBuilder builder,
            ServiceParameterRegistry registry)
        {
            var cacheConfig = registry.GetCacheConfig(builder.Configuration);
            
            project
                .WithEnvironment("CACHE_HOST", cacheConfig.Host)
                .WithEnvironment("CACHE_PORT", cacheConfig.Port.ToString())
                .WithEnvironment("CACHE_INSTANCE_NAME", cacheConfig.InstanceName)
                .WithEnvironment("CACHE_SECURE", cacheConfig.Secure.ToString());

            // Add parameters for secrets
            if (cacheConfig.PasswordParameter != null)
                project.WithParameterEnv("CACHE_PASSWORD", cacheConfig.PasswordParameter);
        }
    }
}
