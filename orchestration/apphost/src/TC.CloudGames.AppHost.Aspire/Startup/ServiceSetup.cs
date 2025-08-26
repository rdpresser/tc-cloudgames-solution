using Microsoft.Extensions.Configuration;
using TC.CloudGames.AppHost.Aspire.Extensions;

namespace TC.CloudGames.AppHost.Aspire.Startup
{
    public static class ServiceSetup
    {
        public static (IResourceBuilder<PostgresServerResource> postgres,
            IResourceBuilder<PostgresDatabaseResource> userDb,
            IResourceBuilder<PostgresDatabaseResource> gameDb,
            IResourceBuilder<PostgresDatabaseResource> paymentDb,
            IResourceBuilder<PostgresDatabaseResource> maintenanceDb) ConfigurePostgres(
                IDistributedApplicationBuilder builder,
                ParameterRegistry registry)
        {
            ValidatePostgresParameters(registry);

            var databaseNames = GetDatabaseNames(builder.Configuration);
            var postgres = CreatePostgresServer(builder, registry);
            var databases = CreateDatabases(postgres, databaseNames);

            return (postgres, databases.userDb, databases.gameDb, databases.paymentDb, databases.maintenanceDb);
        }

        public static IResourceBuilder<RedisResource> ConfigureRedis(IDistributedApplicationBuilder builder, ParameterRegistry registry)
        {
            var redisPort = int.Parse(registry["redis-port"].Value!);

            return builder.AddRedis(
                    name: builder.Configuration["Cache:Host"]!,
                    port: redisPort,
                    password: registry["redis-password"].Resource)
                .WithImage("redis:latest")
                .WithContainerName("TC-CloudGames-Redis")
                .WithDataVolume("tccloudgames_redis_data", isReadOnly: false);
        }

        public static IResourceBuilder<RabbitMQServerResource> ConfigureRabbitMQ(IDistributedApplicationBuilder builder, ParameterRegistry registry)
        {
            return builder.AddRabbitMQ(
                    name: builder.Configuration["RabbitMq:Host"]!,
                    userName: registry["rabbitmq-user"].Resource,
                    password: registry["rabbitmq-password"].Resource,
                    port: 5672) // Standard AMQP port
                .WithContainerName("TC-CloudGames-RabbitMq")
                .WithDataVolume("tccloudgames_rabbitmq_data", isReadOnly: false)
                .WithManagementPlugin(15672); // Standard management port
        }

        private static void ValidatePostgresParameters(ParameterRegistry registry)
        {
            if (!registry.Contains("postgres-user") || !registry.Contains("postgres-password"))
                throw new InvalidOperationException("Missing Postgres credentials in ParameterRegistry.");
        }

        private static (string users, string games, string payments, string maintenance) GetDatabaseNames(ConfigurationManager configuration)
        {
            return (
                users: configuration["Database:UsersDbName"]!,
                games: configuration["Database:GamesDbName"]!,
                payments: configuration["Database:PaymentsDbName"]!,
                maintenance: configuration["Database:MaintenanceDbName"]!
            );
        }

        private static IResourceBuilder<PostgresServerResource> CreatePostgresServer(IDistributedApplicationBuilder builder, ParameterRegistry registry)
        {
            return builder.AddPostgres(builder.Configuration["Database:Host"]!)
                .WithImage("postgres:latest")
                .WithContainerName("TC-CloudGames-Db")
                .WithDataVolume("tccloudgames_postgres_data", isReadOnly: false)
                .WithPgAdmin(options => options
                    .WithImage("dpage/pgadmin4:latest")
                    .WithVolume("tccloudgames_pgadmin_data", "/var/lib/pgadmin")
                    .WithContainerName("TC-CloudGames-PgAdmin4"))
                .WithUserName(registry["postgres-user"].Resource)
                .WithPassword(registry["postgres-password"].Resource)
                .WithHostPort(5432); // Standard PostgreSQL port
        }

        private static (IResourceBuilder<PostgresDatabaseResource> userDb,
            IResourceBuilder<PostgresDatabaseResource> gameDb,
            IResourceBuilder<PostgresDatabaseResource> paymentDb,
            IResourceBuilder<PostgresDatabaseResource> maintenanceDb) CreateDatabases(
            IResourceBuilder<PostgresServerResource> postgres,
            (string users, string games, string payments, string maintenance) databaseNames)
        {
            var userDb = postgres.AddDatabase("UsersDbConnection", databaseNames.users);
            var gameDb = postgres.AddDatabase("GamesDbConnection", databaseNames.games);
            var paymentDb = postgres.AddDatabase("PaymentsDbConnection", databaseNames.payments);
            var maintenanceDb = postgres.AddDatabase("MaintenanceDbConnection", databaseNames.maintenance);

            return (userDb, gameDb, paymentDb, maintenanceDb);
        }
    }
}