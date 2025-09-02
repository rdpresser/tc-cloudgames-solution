using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Extensions;
using TC.CloudGames.AppHost.Aspire.Startup;

var builder = DistributedApplication.CreateBuilder(args);

// Configure environment variables from .env files
builder.ConfigureEnvironmentVariables();

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

// Setup projects
ProjectSetup.ConfigureUsersApi(builder, registry, postgres, userDb, maintenanceDb, redis, messageBroker);

// Run
await builder.Build().RunAsync();