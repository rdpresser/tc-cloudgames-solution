using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ParameterSetup
    {
        public static ParameterRegistry ConfigureParameters(IDistributedApplicationBuilder builder, ILogger logger)
        {
            var registry = new ParameterRegistry();

            ConfigurePostgresParameters(builder, registry);
            ConfigureRabbitMqParameters(builder, registry);
            ConfigureRedisParameters(builder, registry);

            registry.LogAll(builder.Configuration, logger);
            return registry;
        }

        private static void ConfigurePostgresParameters(IDistributedApplicationBuilder builder, ParameterRegistry registry)
        {
            registry.Add(builder, "postgres-user", "Database:User", "DB_USER", "postgres");
            registry.Add(builder, "postgres-password", "Database:Password", "DB_PASSWORD", "postgres", secret: true);
        }

        private static void ConfigureRabbitMqParameters(IDistributedApplicationBuilder builder, ParameterRegistry registry)
        {
            registry.Add(builder, "rabbitmq-user", "RabbitMq:UserName", "RABBITMQ_USERNAME", "guest");
            registry.Add(builder, "rabbitmq-password", "RabbitMq:Password", "RABBITMQ_PASSWORD", "guest", secret: true);
        }

        private static void ConfigureRedisParameters(IDistributedApplicationBuilder builder, ParameterRegistry registry)
        {
            registry.Add(builder, "redis-password", "Cache:Password", "CACHE_PASSWORD", "Redis@123", secret: true);
            registry.Add(builder, "redis-port", "Cache:Port", "CACHE_PORT", "6379"); // Fixed default port
        }
    }
}
