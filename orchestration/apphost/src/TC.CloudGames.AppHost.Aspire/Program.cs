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

// Detect if we're running with Functions profile
var isAspireFunctionProfile = DetectAspireFunctionProfile();
logger.LogInformation("🔍 Detecting profile: Aspire_Function = {IsAspireFunctionProfile}", isAspireFunctionProfile);

// Setup parameters
var registry = ParameterSetup.ConfigureParameters(builder, logger);

// Setup services
var (postgres, userDb, gamesDb, paymentsDb, maintenanceDb) = ServiceSetup.ConfigurePostgres(builder, registry, logger);
var redis = ServiceSetup.ConfigureRedis(builder, registry, logger);
var messageBroker = ServiceSetup.ConfigureMessageBroker(builder, registry, logger);

// Configure Azurite if Functions profile is detected or AZURITE_AUTO_START is true
IResourceBuilder<IResource>? azurite = null;
if (isAspireFunctionProfile || Environment.GetEnvironmentVariable("AZURITE_AUTO_START") == "true")
{
    azurite = ServiceSetup.ConfigureAzurite(builder, logger);
}

// Setup projects - cada projeto com seu banco específico
var usersApi = ProjectSetup.ConfigureUsersApi(builder, registry, postgres, userDb, maintenanceDb, redis, messageBroker);
var gamesApi = ProjectSetup.ConfigureGamesApi(builder, registry, usersApi, postgres, gamesDb, maintenanceDb, redis, messageBroker);
ProjectSetup.ConfigurePaymentsApi(builder, registry, gamesApi, postgres, paymentsDb, maintenanceDb, redis, messageBroker);

// Configure Functions if profile is detected or explicitly enabled
if (isAspireFunctionProfile && azurite != null)
{
    ProjectSetup.ConfigureFunctions(builder, registry, azurite, messageBroker, logger);
}

// Run
await builder.Build().RunAsync();

/// <summary>
/// Detecta se o profile Aspire_Function está sendo usado
/// </summary>
static bool DetectAspireFunctionProfile()
{
    // Verifica múltiplas formas de detectar o profile
    var launchProfile = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
    var dotnetEnvironment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
    var azuriteAutoStart = Environment.GetEnvironmentVariable("AZURITE_AUTO_START");
    
    // Verifica se há indicadores do profile Aspire_Function
    var hasAzuriteAutoStart = string.Equals(azuriteAutoStart, "true", StringComparison.OrdinalIgnoreCase);
    
    // Verifica argumentos da linha de comando
    var args = Environment.GetCommandLineArgs();
    var hasProfileArg = args.Any(arg => 
        arg.Contains("Aspire_Function", StringComparison.OrdinalIgnoreCase) ||
        arg.Contains("--launch-profile", StringComparison.OrdinalIgnoreCase) && 
        args.Any(a => a.Contains("Aspire_Function", StringComparison.OrdinalIgnoreCase)));
    
    return hasAzuriteAutoStart || hasProfileArg;
}