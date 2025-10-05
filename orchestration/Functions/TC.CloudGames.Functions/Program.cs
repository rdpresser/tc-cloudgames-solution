var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices((context, services) =>
    {
        // Carrega variáveis adicionais do .env se estivermos em ambiente local
        EnvironmentVariablesConfigurator.LoadFromEnvFilesIfLocal();

        var connectionString = Environment.GetEnvironmentVariable("SERVICEBUS_CONNECTION");
        Console.WriteLine($"Connection String encontrada: {(!string.IsNullOrEmpty(connectionString))}");
        ArgumentNullException.ThrowIfNull(connectionString);

        services.AddDependencies();
    })
    .Build();

await host.RunAsync().ConfigureAwait(false);
