using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    /// <summary>
    /// Tipos de projetos suportados na solução
    /// </summary>
    public enum ProjectType
    {
        Users,
        Games,
        Payments
    }

    /// <summary>
    /// Configuração base para todos os serviços
    /// </summary>
    public abstract record ServiceConfig
    {
        public bool UseExternalService { get; init; }
        public virtual string ContainerName { get; init; } = string.Empty;
    }

    /// <summary>
    /// Configuração unificada para PostgreSQL
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

        // Recursos Aspire para parâmetros secretos
        public IResourceBuilder<ParameterResource>? UserParameter { get; init; }
        public IResourceBuilder<ParameterResource>? PasswordParameter { get; init; }
    }

    /// <summary>
    /// Configuração unificada para Redis
    /// </summary>
    public record CacheServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-Redis";
        public required string Host { get; init; }
        public required int Port { get; init; }
        public required string Password { get; init; }
        public required Dictionary<string, string> InstanceNames { get; init; }
        public required bool Secure { get; init; }

        // Recursos Aspire para parâmetros secretos
        public IResourceBuilder<ParameterResource>? PasswordParameter { get; init; }

        /// <summary>
        /// Obtém o nome da instância para um projeto específico
        /// </summary>
        public string GetInstanceNameForProject(ProjectType projectType)
        {
            var projectKey = projectType.ToString().ToLowerInvariant();
            return InstanceNames.GetValueOrDefault(projectKey, $"TC.CloudGames.{projectType}.Api:");
        }

        /// <summary>
        /// Cria configuração de cache a partir da configuração do sistema
        /// </summary>
        public static CacheServiceConfig CreateFromConfiguration(
            ConfigurationManager configuration,
            IResourceBuilder<ParameterResource>? passwordParameter = null,
            ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "Cache", logger);

            return new CacheServiceConfig
            {
                UseExternalService = useExternal,
                ContainerName = ServiceConfigResolver.GetResolvedValue("Cache:ContainerName", "CACHE_CONTAINER_NAME", configuration, "TC-CloudGames-Redis", logger),
                Host = ServiceConfigResolver.GetResolvedValue("Cache:Host", "CACHE_HOST", configuration, useExternal ? "" : "localhost", logger),
                Port = int.Parse(ServiceConfigResolver.GetResolvedValue("Cache:Port", "CACHE_PORT", configuration, "6379", logger)),
                Password = ServiceConfigResolver.GetResolvedValue("Cache:Password", "CACHE_PASSWORD", configuration, "Redis@123", logger),
                InstanceNames = ParseInstanceNamesFromConfiguration(configuration, logger),
                Secure = bool.Parse(ServiceConfigResolver.GetResolvedValue("Cache:Secure", "CACHE_SECURE", configuration, "false", logger)),
                PasswordParameter = passwordParameter
            };
        }

        /// <summary>
        /// Parse instance names from configuration, supporting both old and new format
        /// </summary>
        private static Dictionary<string, string> ParseInstanceNamesFromConfiguration(ConfigurationManager configuration, ILogger? logger = null)
        {
            var instanceNames = new Dictionary<string, string>();

            // Try new format first (Cache:InstanceNames:users, etc.)
            var instanceNamesSection = configuration.GetSection("Cache:InstanceNames");
            if (instanceNamesSection.Exists() && instanceNamesSection.GetChildren().Any())
            {
                foreach (var child in instanceNamesSection.GetChildren())
                {
                    instanceNames[child.Key] = child.Value ?? string.Empty;
                }
                logger?.LogDebug("Cache instance names loaded from new format: {Count} entries", instanceNames.Count);
                return instanceNames;
            }

            // Fallback to old format (single InstanceName)
            var singleInstanceName = ServiceConfigResolver.GetResolvedValue("Cache:InstanceName", "CACHE_INSTANCE_NAME", configuration, "TC.CloudGames.Users.Api:", logger);

            // Try to determine project type from single instance name
            if (singleInstanceName.Contains("Users", StringComparison.OrdinalIgnoreCase))
            {
                instanceNames["users"] = singleInstanceName;
            }
            else if (singleInstanceName.Contains("Games", StringComparison.OrdinalIgnoreCase))
            {
                instanceNames["games"] = singleInstanceName;
            }
            else if (singleInstanceName.Contains("Payments", StringComparison.OrdinalIgnoreCase))
            {
                instanceNames["payments"] = singleInstanceName;
            }
            else
            {
                // Default mapping for all project types
                instanceNames["users"] = "TC.CloudGames.Users.Api:";
                instanceNames["games"] = "TC.CloudGames.Games.Api:";
                instanceNames["payments"] = "TC.CloudGames.Payments.Api:";
                logger?.LogWarning("Could not parse instance name '{InstanceName}', using default mappings", singleInstanceName);
            }

            logger?.LogDebug("Cache instance names loaded from legacy format: {Count} entries", instanceNames.Count);
            return instanceNames;
        }
    }

    /// <summary>
    /// Configuração unificada para RabbitMQ
    /// </summary>
    public record RabbitMqServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-RabbitMq";
        public required string Host { get; init; }
        public required int Port { get; init; }
        public required string VirtualHost { get; init; }
        public required string UserName { get; init; }
        public required string Password { get; init; }
        public required string UsersExchange { get; init; }
        public required string GamesExchange { get; init; }
        public required string PaymentsExchange { get; init; }
        public required bool AutoProvision { get; init; }
        public required bool Durable { get; init; }
        public required bool UseQuorumQueues { get; init; }
        public required bool AutoPurgeOnStartup { get; init; } = false;

        // Recursos Aspire para parâmetros secretos
        public IResourceBuilder<ParameterResource>? UserParameter { get; init; }
        public IResourceBuilder<ParameterResource>? PasswordParameter { get; init; }

        /// <summary>
        /// Retorna o exchange correto baseado no tipo de projeto
        /// </summary>
        public string GetExchangeForProject(ProjectType projectType) => projectType switch
        {
            ProjectType.Users => UsersExchange,
            ProjectType.Games => GamesExchange,
            ProjectType.Payments => PaymentsExchange,
            _ => UsersExchange
        };
    }

    /// <summary>
    /// Configuração unificada para Azure Service Bus
    /// </summary>
    public record AzureServiceBusServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-AzureServiceBus";
        public required string ConnectionString { get; init; }
        public required string UsersTopicName { get; init; }
        public required string GamesTopicName { get; init; }
        public required string PaymentsTopicName { get; init; }
        public required bool AutoProvision { get; init; }
        public required int MaxDeliveryCount { get; init; }
        public required bool EnableDeadLettering { get; init; }
        public required bool AutoPurgeOnStartup { get; init; } = false;
        public required bool UseControlQueues { get; init; }

        // Recursos Aspire para parâmetros secretos
        public IResourceBuilder<ParameterResource>? ConnectionStringParameter { get; init; }

        /// <summary>
        /// Retorna o topicName correto baseado no tipo de projeto
        /// </summary>
        public string GetTopicNameForProject(ProjectType projectType) => projectType switch
        {
            ProjectType.Users => UsersTopicName,
            ProjectType.Games => GamesTopicName,
            ProjectType.Payments => PaymentsTopicName,
            _ => UsersTopicName
        };
    }

    /// <summary>
    /// Helper para resolver configurações de serviços
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

            // 1. Prioridade: Variável de ambiente
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

            // 3. Terceira prioridade: Valor padrão
            if (!string.IsNullOrEmpty(defaultValue))
            {
                sources.Add(("Default Value", defaultValue));
                logger?.LogDebug("Config '{ConfigKey}' using default value: {Value}", configKey, defaultValue);
                return defaultValue;
            }

            // 4. Se não encontrou, exceção
            logger?.LogError("Configuration '{ConfigKey}' not found in any source. Checked sources: {Sources}",
                configKey, string.Join(", ", sources.Select(s => $"{s.source}: {(s.value ?? "null")}")));

            throw new InvalidOperationException(
                $"Required configuration '{configKey}' not found. " +
                $"Checked: {string.Join(", ", sources.Select(s => s.source))}");
        }

        /// <summary>
        /// Determina se deve usar serviço externo baseado na configuração
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

    public record class ElasticServiceConfig : ServiceConfig
    {
        public required string Host { get; init; }
        public required string Port { get; init; }
        public required string Username { get; init; }
        public required string Password { get; init; }
        public required string IndexName { get; init; }
    }
}