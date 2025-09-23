using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Extensions;
using TC.CloudGames.AppHost.Aspire.Startup;

var builder = DistributedApplication.CreateBuilder(args);

// Configure environment variables from .env files
builder.ConfigureEnvironmentVariables();

// Elasticsearch container
var elastic = builder.AddContainer("elasticsearch", "docker.elastic.co/elasticsearch/elasticsearch", "8.10.2")
    .WithEnvironment("discovery.type", "single-node")
    .WithEnvironment("xpack.security.enabled", "false")
    .WithEnvironment("ES_JAVA_OPTS", "-Xms512m -Xmx512m")
    .WithHttpEndpoint(name: "http", port: 9200, targetPort: 9200);

// Kibana container
var kibana = builder.AddContainer("kibana", "docker.elastic.co/kibana/kibana", "8.10.2")
    .WithEnvironment("ELASTICSEARCH_HOSTS", "http://elasticsearch:9200")
    .WithHttpEndpoint(port: 5601, targetPort: 5601);

// Setup logger
var loggerFactory = LoggerFactory.Create(config =>
{
    config.AddConsole();
    config.SetMinimumLevel(LogLevel.Information);
});
var logger = loggerFactory.CreateLogger("Startup");

// Setup parameters
var registry = ParameterSetup.ConfigureParameters(builder, logger);

// Setup services
var (postgres, userDb, gamesDb, paymentsDb, maintenanceDb) = ServiceSetup.ConfigurePostgres(builder, registry, logger);
var redis = ServiceSetup.ConfigureRedis(builder, registry, logger);
var messageBroker = ServiceSetup.ConfigureMessageBroker(builder, registry, logger);

// Setup projects - cada projeto com seu banco específico
var usersApi = ProjectSetup.ConfigureUsersApi(builder, registry, postgres, userDb, maintenanceDb, redis, messageBroker);
var gamesApi = ProjectSetup.ConfigureGamesApi(builder, registry, usersApi, postgres, gamesDb, maintenanceDb, redis, messageBroker);
ProjectSetup.ConfigurePaymentsApi(builder, registry, gamesApi, postgres, paymentsDb, maintenanceDb, redis, messageBroker);

// Run
await builder.Build().RunAsync();