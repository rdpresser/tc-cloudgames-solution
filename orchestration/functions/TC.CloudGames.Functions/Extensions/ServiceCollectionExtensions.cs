using Microsoft.AspNetCore.Builder;

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
            
            return services;
        }
    }
}
