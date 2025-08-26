using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ProjectSetup
    {
        public static void ConfigureUsersApi(
            IDistributedApplicationBuilder builder,
            ParameterRegistry registry,
            IResourceBuilder<PostgresServerResource> postgres,
            IResourceBuilder<PostgresDatabaseResource> userDb,
            IResourceBuilder<PostgresDatabaseResource> maintenanceDb,
            IResourceBuilder<RedisResource> redis,
            IResourceBuilder<RabbitMQServerResource> rabbit)
        {
            var project = builder.AddProject<Projects.TC_CloudGames_Users_Api>("users-api")
                .WithHealthChecks()
                .WithServiceReferences(postgres, userDb, maintenanceDb, redis, rabbit);

            ConfigureDatabaseEnvironment(project, builder, registry, userDb, maintenanceDb);
            ConfigureMessageBrokerEnvironment(project, builder, registry);
            ConfigureCacheEnvironment(project, builder, registry);
        }

        private static IResourceBuilder<ProjectResource> WithHealthChecks(this IResourceBuilder<ProjectResource> project)
        {
            return project
                .WithHttpHealthCheck("/health")
                .WithHttpHealthCheck("/ready")
                .WithHttpHealthCheck("/live");
        }

        private static IResourceBuilder<ProjectResource> WithServiceReferences(
            this IResourceBuilder<ProjectResource> project,
            IResourceBuilder<PostgresServerResource> postgres,
            IResourceBuilder<PostgresDatabaseResource> userDb,
            IResourceBuilder<PostgresDatabaseResource> maintenanceDb,
            IResourceBuilder<RedisResource> redis,
            IResourceBuilder<RabbitMQServerResource> rabbit)
        {
            return project
                .WithReference(postgres)      // Needed for schema/table creation via Marten/Wolverine
                .WithReference(userDb)        // Needed for DB connection
                .WithReference(maintenanceDb)
                .WithReference(redis)
                .WithReference(rabbit);
        }

        private static void ConfigureDatabaseEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ParameterRegistry registry,
            IResourceBuilder<PostgresDatabaseResource> userDb,
            IResourceBuilder<PostgresDatabaseResource> maintenanceDb)
        {
            project
                .WithEnvironment("DB_HOST", "localhost")
                .WithEnvironment("DB_PORT", builder.Configuration["Database:Port"] ?? "5432")
                .WithEnvironment("DB_NAME", userDb.Resource.DatabaseName)
                .WithEnvironment("DB_MAINTENANCE_NAME", maintenanceDb.Resource.DatabaseName)
                .WithParameterEnv("DB_USER", registry["postgres-user"])
                .WithParameterEnv("DB_PASSWORD", registry["postgres-password"]);
        }

        private static void ConfigureMessageBrokerEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ParameterRegistry registry)
        {
            project
                .WithEnvironment("RABBITMQ_HOST", "localhost")
                .WithEnvironment("RABBITMQ_PORT", builder.Configuration["RabbitMq:Port"] ?? "5672")
                .WithEnvironment("RABBITMQ_VHOST", builder.Configuration["RabbitMq:VirtualHost"] ?? "/")
                .WithEnvironment("RABBITMQ_EXCHANGE", builder.Configuration["RabbitMq:Exchange"] ?? "user.events")
                .WithParameterEnv("RABBITMQ_USERNAME", registry["rabbitmq-user"])
                .WithParameterEnv("RABBITMQ_PASSWORD", registry["rabbitmq-password"]);
        }

        private static void ConfigureCacheEnvironment(
            IResourceBuilder<ProjectResource> project,
            IDistributedApplicationBuilder builder,
            ParameterRegistry registry)
        {
            project
                .WithEnvironment("CACHE_HOST", "localhost")
                .WithEnvironment("CACHE_PORT", builder.Configuration["Cache:Port"] ?? "6379")
                .WithEnvironment("CACHE_SECURE", "false")
                .WithParameterEnv("CACHE_PASSWORD", registry["redis-password"]);
        }
    }
}
