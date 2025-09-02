using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    /// <summary>
    /// Configura��o base para todos os servi�os
    /// </summary>
    public abstract record ServiceConfig
    {
        public bool UseExternalService { get; init; }
        public virtual string ContainerName { get; init; } = string.Empty;
    }

    /// <summary>
    /// Configura��o unificada para PostgreSQL
    /// </summary>
    public record DatabaseServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-Postgres";
        public required string Host { get; init; }
        public required int Port { get; init; }
        public required string UsersDbName { get; init; }
        public required string GamesDbName { get; init; }
        public required string PaymentsDbName { get; init; }
        public required string MaintenanceDbName { get; init; }
        public required string User { get; init; }
        public required string Password { get; init; }
        public required string Schema { get; init; }
        public required int ConnectionTimeout { get; init; }

        // Recursos Aspire para par�metros secretos
        public IResourceBuilder<ParameterResource>? UserParameter { get; init; }
        public IResourceBuilder<ParameterResource>? PasswordParameter { get; init; }
    }

    /// <summary>
    /// Configura��o unificada para Redis
    /// </summary>
    public record CacheServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-Redis";
        public required string Host { get; init; }
        public required int Port { get; init; }
        public required string Password { get; init; }
        public required string InstanceName { get; init; }
        public required bool Secure { get; init; }

        // Recursos Aspire para par�metros secretos
        public IResourceBuilder<ParameterResource>? PasswordParameter { get; init; }
    }

    /// <summary>
    /// Configura��o unificada para RabbitMQ
    /// </summary>
    public record RabbitMqServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-RabbitMq";
        public required string Host { get; init; }
        public required int Port { get; init; }
        public required string VirtualHost { get; init; }
        public required string UserName { get; init; }
        public required string Password { get; init; }
        public required string Exchange { get; init; }
        public required bool AutoProvision { get; init; }
        public required bool Durable { get; init; }
        public required bool UseQuorumQueues { get; init; }
        public required bool AutoPurgeOnStartup { get; init; }

        // Recursos Aspire para par�metros secretos
        public IResourceBuilder<ParameterResource>? UserParameter { get; init; }
        public IResourceBuilder<ParameterResource>? PasswordParameter { get; init; }
    }

    /// <summary>
    /// Configura��o unificada para Azure Service Bus
    /// </summary>
    public record AzureServiceBusServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-AzureServiceBus";
        public required string ConnectionString { get; init; }
        public required string TopicName { get; init; }
        public required string SubscriptionName { get; init; }
        public required bool AutoProvision { get; init; }
        public required int MaxDeliveryCount { get; init; }
        public required bool EnableDeadLettering { get; init; }
        public required bool AutoPurgeOnStartup { get; init; }
        public required bool UseControlQueues { get; init; }

        // Recursos Aspire para par�metros secretos
        public IResourceBuilder<ParameterResource>? ConnectionStringParameter { get; init; }
    }

    /// <summary>
    /// Helper para resolver configura��es de servi�os
    /// </summary>
    public static class ServiceConfigResolver
    {
        /// <summary>
        /// Resolve valor com fallback: ENV ? Configuration ? Default
        /// </summary>
        public static string GetResolvedValue(
            string configKey,
            string envVarName,
            ConfigurationManager configuration,
            string? defaultValue = null,
            ILogger? logger = null)
        {
            var sources = new List<(string source, string? value)>();

            // 1. Prioridade: Vari�vel de ambiente
            var envValue = Environment.GetEnvironmentVariable(envVarName);
            sources.Add(($"Environment Variable '{envVarName}'", envValue));

            if (!string.IsNullOrEmpty(envValue))
            {
                logger?.LogDebug("Config '{ConfigKey}' found in environment variable '{EnvVar}': {Value}",
                    configKey, envVarName, envValue);
                return envValue;
            }

            // 2. Segunda prioridade: Configuration
            var configValue = configuration[configKey];
            sources.Add(($"Configuration '{configKey}'", configValue));

            if (!string.IsNullOrEmpty(configValue))
            {
                logger?.LogDebug("Config '{ConfigKey}' found in configuration: {Value}", configKey, configValue);
                return configValue;
            }

            // 3. Terceira prioridade: Valor padr�o
            if (!string.IsNullOrEmpty(defaultValue))
            {
                sources.Add(("Default Value", defaultValue));
                logger?.LogDebug("Config '{ConfigKey}' using default value: {Value}", configKey, defaultValue);
                return defaultValue;
            }

            // 4. Se n�o encontrou, exce��o
            logger?.LogError("Configuration '{ConfigKey}' not found in any source. Checked sources: {Sources}",
                configKey, string.Join(", ", sources.Select(s => $"{s.source}: {(s.value ?? "null")}")));

            throw new InvalidOperationException(
                $"Required configuration '{configKey}' not found. " +
                $"Checked: {string.Join(", ", sources.Select(s => s.source))}");
        }

        /// <summary>
        /// Determina se deve usar servi�o externo baseado na configura��o
        /// </summary>
        public static bool ShouldUseExternalService(
            ConfigurationManager configuration,
            string serviceKey,
            ILogger? logger = null)
        {
            var useExternal = bool.Parse(GetResolvedValue(
                $"{serviceKey}:UseExternalService",
                $"USE_EXTERNAL_{serviceKey.ToUpperInvariant()}",
                configuration,
                "false",
                logger));

            logger?.LogInformation(useExternal
                ? "?? Using external {ServiceKey} service"
                : "?? Using local {ServiceKey} container", serviceKey);

            return useExternal;
        }
    }
}