using Azure.Identity;
using Microsoft.Extensions.Azure;

namespace TC.CloudGames.Functions.Extensions
{
    internal static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddDependencies(this IServiceCollection services)
        {
            services.AddSingleton<ISendGridClient>(provider =>
            {
                var apiKey = Environment.GetEnvironmentVariable("SENDGRID_API_KEY");
                if (string.IsNullOrWhiteSpace(apiKey))
                {
                    throw new InvalidOperationException("SendGrid API key is not configured.");
                }
                return new SendGridClient(apiKey);
            });

            services.AddScoped<ISendGridService, SendGridService>();

            // Configurar Service Bus client com detecção automática de ambiente
            ConfigureServiceBusClient(services);

            return services;
        }

        private static void ConfigureServiceBusClient(IServiceCollection services)
        {
            var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production";
            var connectionString = Environment.GetEnvironmentVariable("SERVICEBUS_CONNECTION");
            var fullyQualifiedNamespace = Environment.GetEnvironmentVariable("SERVICEBUS_NAMESPACE");

            Console.WriteLine($"🌍 Ambiente detectado: {environment}");

            // Em Development (localhost), usa connection string
            if (environment.Equals("Development", StringComparison.OrdinalIgnoreCase))
            {
                if (!string.IsNullOrEmpty(connectionString))
                {
                    Console.WriteLine("🔑 [Development] Configurando Service Bus com Connection String");
                    services.AddAzureClients(builder =>
                    {
                        builder.AddServiceBusClient(connectionString);
                    });
                    
                    // Configurar a variável para o trigger funcionar
                    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus", connectionString);
                }
                else
                {
                    throw new InvalidOperationException("⚠️ SERVICEBUS_CONNECTION é obrigatório em ambiente Development");
                }
            }
            // Em produção (Azure), usa Managed Identity com namespace
            else
            {
                if (!string.IsNullOrEmpty(fullyQualifiedNamespace))
                {
                    Console.WriteLine($"🔐 [Production] Configurando Service Bus com Managed Identity: {fullyQualifiedNamespace}");
                    services.AddAzureClients(builder =>
                    {
                        builder.AddServiceBusClient(fullyQualifiedNamespace)
                               .WithCredential(new DefaultAzureCredential());
                    });
                    
                    // CRÍTICO: Service Bus Trigger precisa de ambas as configurações
                    // Formato: AzureWebJobsServiceBus__fullyQualifiedNamespace
                    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus__fullyQualifiedNamespace", fullyQualifiedNamespace);
                    
                    // IMPORTANTE: Também deve ter credential configurada no host
                    // Isso permite que o trigger use Managed Identity automaticamente
                }
                else if (!string.IsNullOrEmpty(connectionString))
                {
                    // Fallback: se namespace não estiver configurado mas connection string sim (Key Vault)
                    Console.WriteLine("🔑 [Production Fallback] Configurando Service Bus com Connection String do Key Vault");
                    services.AddAzureClients(builder =>
                    {
                        builder.AddServiceBusClient(connectionString);
                    });
                    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus", connectionString);
                }
                else
                {
                    throw new InvalidOperationException("⚠️ SERVICEBUS_NAMESPACE ou SERVICEBUS_CONNECTION é obrigatório em ambiente de produção (Azure)");
                }
            }

            Console.WriteLine("✅ Service Bus configurado com sucesso");
        }
    }
}
