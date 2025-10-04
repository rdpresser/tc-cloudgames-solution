using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using SendGrid;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices((context, services) =>
    {
        var sendGridApiKey = Environment.GetEnvironmentVariable("SENDGRID_API_KEY");

        if (string.IsNullOrWhiteSpace(sendGridApiKey))
            throw new InvalidOperationException("SENDGRID_API_KEY não foi configurada");

        services.AddSingleton(new SendGridClient(sendGridApiKey));
    })
    .Build();

host.Run();
