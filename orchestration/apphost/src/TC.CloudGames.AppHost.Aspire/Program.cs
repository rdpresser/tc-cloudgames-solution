using Microsoft.Extensions.Logging;
using TC.CloudGames.AppHost.Aspire.Startup;

var builder = DistributedApplication.CreateBuilder(args);

// Load environment variables from .env files
var environment = builder.Environment.EnvironmentName.ToLowerInvariant();

// Find project root by looking for solution file or git directory
var projectRoot = FindProjectRoot() ?? Directory.GetCurrentDirectory();

// Load base .env file first (if exists)
var baseEnvFile = Path.Combine(projectRoot, ".env");
if (File.Exists(baseEnvFile))
{
    DotNetEnv.Env.Load(baseEnvFile);
    Console.WriteLine($"Loaded base .env from: {baseEnvFile}");
}

// Load environment-specific .env file (overrides base values)
var envFile = Path.Combine(projectRoot, $".env.{environment}");
if (File.Exists(envFile))
{
    DotNetEnv.Env.Load(envFile);
    Console.WriteLine($"Loaded {environment} .env from: {envFile}");
}
else
{
    Console.WriteLine($"Environment file not found: {envFile}");
}

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

static string? FindProjectRoot()
{
    var directory = new DirectoryInfo(Directory.GetCurrentDirectory());

    while (directory != null)
    {
        // Look for common project root indicators
        if (directory.GetFiles("*.sln").Length > 0 ||
            directory.GetDirectories(".git").Length > 0 ||
            HasEnvFiles(directory))
        {
            return directory.FullName;
        }
        directory = directory.Parent;
    }

    return null;
}

static bool HasEnvFiles(DirectoryInfo directory)
{
    return directory.GetFiles(".env").Length > 0 ||
           directory.GetFiles(".env.*").Length > 0;
}