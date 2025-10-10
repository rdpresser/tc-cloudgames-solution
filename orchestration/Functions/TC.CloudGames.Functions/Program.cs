using TC.CloudGames.Functions.Extensions;
using System.Collections;

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
        
        // Melhor logging para diagnosticar o problema
        if (string.IsNullOrEmpty(connectionString))
        {
            Console.WriteLine("? ERRO: SERVICEBUS_CONNECTION não foi encontrada nas variáveis de ambiente!");
            Console.WriteLine("Variáveis disponíveis:");
            foreach (DictionaryEntry env in Environment.GetEnvironmentVariables())
            {
                if (env.Key.ToString().Contains("SERVICE", StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine($"  {env.Key} = {env.Value}");
                }
            }
        }
        else
        {
            Console.WriteLine($"? SERVICEBUS_CONNECTION configurada (length: {connectionString.Length})");
        }
        
        ArgumentNullException.ThrowIfNull(connectionString);

        services.AddDependencies();
    })
    .Build();

await host.RunAsync().ConfigureAwait(false);
