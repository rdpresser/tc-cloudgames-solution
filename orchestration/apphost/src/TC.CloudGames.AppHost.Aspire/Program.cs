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

// Configure Azurite if AZURITE_AUTO_START is enabled
IResourceBuilder<IResource>? azurite = null;
if (Environment.GetEnvironmentVariable("AZURITE_AUTO_START") == "true")
{
    azurite = ServiceSetup.ConfigureAzurite(builder, logger);
}

// Setup projects - cada projeto com seu banco específico
var usersApi = ProjectSetup.ConfigureUsersApi(builder, registry, postgres, userDb, maintenanceDb, redis, messageBroker);
var gamesApi = ProjectSetup.ConfigureGamesApi(builder, registry, usersApi, postgres, gamesDb, maintenanceDb, redis, messageBroker);
ProjectSetup.ConfigurePaymentsApi(builder, registry, gamesApi, postgres, paymentsDb, maintenanceDb, redis, messageBroker);

// Configure Functions if Azurite is available
if (azurite != null)
{
    ProjectSetup.ConfigureFunctions(builder, registry, azurite, messageBroker, logger);
}

// Run
await builder.Build().RunAsync();