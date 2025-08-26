using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Startup;

var builder = DistributedApplication.CreateBuilder(args);

// Load .env variables
DotNetEnv.Env.Load(Path.Combine("./", ".env"));

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
var (postgres, userDb, gamesDb, paymentsDb, maintenanceDb) = ServiceSetup.ConfigurePostgres(builder, registry);
var redis = ServiceSetup.ConfigureRedis(builder, registry);
var rabbit = ServiceSetup.ConfigureRabbitMQ(builder, registry);

// Setup projects
ProjectSetup.ConfigureUsersApi(builder, registry, postgres, userDb, maintenanceDb, redis, rabbit);

// Run
await builder.Build().RunAsync();