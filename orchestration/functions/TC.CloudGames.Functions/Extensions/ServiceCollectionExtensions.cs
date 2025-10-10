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

            // Configurar Service Bus client para suportar Managed Identity
            ConfigureServiceBusClient(services);

            return services;
        }

        private static void ConfigureServiceBusClient(IServiceCollection services)
        {
            var connectionString = Environment.GetEnvironmentVariable("SERVICEBUS_CONNECTION");
            var fullyQualifiedNamespace = Environment.GetEnvironmentVariable("SERVICEBUS_NAMESPACE");

            // Se estiver rodando no Azure com Managed Identity
            if (!string.IsNullOrEmpty(fullyQualifiedNamespace) && string.IsNullOrEmpty(connectionString))
            {
                Console.WriteLine($"🔐 Configurando Service Bus com Managed Identity: {fullyQualifiedNamespace}");

                services.AddAzureClients(builder =>
                {
                    builder.AddServiceBusClient(fullyQualifiedNamespace);
                });
            }
            else if (!string.IsNullOrEmpty(connectionString))
            {
                Console.WriteLine("🔑 Configurando Service Bus com Connection String");

                services.AddAzureClients(builder =>
                {
                    builder.AddServiceBusClient(connectionString);
                });
            }
            else
            {
                Console.WriteLine("⚠️ Service Bus não configurado - nem connection string nem namespace encontrado");
            }
        }
    }
}
