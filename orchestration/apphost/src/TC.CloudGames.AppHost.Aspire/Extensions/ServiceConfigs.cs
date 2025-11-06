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
        public required string UsersDbName { get; init; }
        public required string GamesDbName { get; init; }
        public required string PaymentsDbName { get; init; }
    }

    /// <summary>
    /// Configuração unificada para Redis
    /// </summary>
    public record CacheServiceConfig : ServiceConfig
    {
        public override string ContainerName { get; init; } = "TC-CloudGames-Redis";
        public required Dictionary<string, string> InstanceNames { get; init; }
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
                ContainerName = ServiceConfigResolver.GetConfigurationValue("Cache:ContainerName", configuration, "TC-CloudGames-Redis", logger),
                InstanceNames = ParseInstanceNamesFromConfiguration(configuration, logger)
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
            var singleInstanceName = ServiceConfigResolver.GetConfigurationValue("Cache:InstanceName", configuration, "TC.CloudGames.Users.Api:", logger);

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
        public required string UsersExchange { get; init; }
        public required string GamesExchange { get; init; }
        public required string PaymentsExchange { get; init; }
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
        public required string UsersTopicName { get; init; }
        public required string GamesTopicName { get; init; }
        public required string PaymentsTopicName { get; init; }
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
    /// Configuração unificada para Grafana Cloud
    /// </summary>
    public record GrafanaCloudServiceConfig : ServiceConfig
    {
        public required string GrafanaOtelGamesResourceAttributes { get; init; }
        public required string GrafanaOtelUsersResourceAttributes { get; init; }
        public required string GrafanaOtelPaymentsResourceAttributes { get; init; }
        /// <summary>
        /// Retorna os Resource Attributes corretos baseado no tipo de projeto
        /// </summary>
        public string GetOtelResourceAttributesForProject(ProjectType projectType) => projectType switch
        {
            ProjectType.Users => GrafanaOtelUsersResourceAttributes,
            ProjectType.Games => GrafanaOtelGamesResourceAttributes,
            ProjectType.Payments => GrafanaOtelPaymentsResourceAttributes,
            _ => throw new ArgumentException($"Tipo de projeto não suportado: {projectType}")
        };

        /// <summary>
        /// Cria configuração do Grafana Cloud a partir da configuração do sistema
        /// </summary>
        public static GrafanaCloudServiceConfig CreateFromConfiguration(
            ConfigurationManager configuration,
            ILogger? logger = null)
        {
            var useExternal = ServiceConfigResolver.ShouldUseExternalService(configuration, "GrafanaCloud", logger);

            return new GrafanaCloudServiceConfig
            {
                UseExternalService = useExternal,
                ContainerName = ServiceConfigResolver.GetConfigurationValue("GrafanaCloud:ContainerName", configuration, "TC-CloudGames-GrafanaCloud", logger),
                GrafanaOtelGamesResourceAttributes = ServiceConfigResolver.GetConfigurationValue("GrafanaCloud:GrafanaOtelGamesResourceAttributes", configuration, "service.name=tccloudgames-games,service.namespace=tccloudgames,deployment.environment=production", logger),
                GrafanaOtelUsersResourceAttributes = ServiceConfigResolver.GetConfigurationValue("GrafanaCloud:GrafanaOtelUsersResourceAttributes", configuration, "service.name=tccloudgames-users,service.namespace=tccloudgames,deployment.environment=production", logger),
                GrafanaOtelPaymentsResourceAttributes = ServiceConfigResolver.GetConfigurationValue("GrafanaCloud:GrafanaOtelPaymentsResourceAttributes", configuration, "service.name=tccloudgames-payments,service.namespace=tccloudgames,deployment.environment=production", logger),
            };
        }
    }

    /// <summary>
    /// Helper para resolver configurações de serviços
    /// </summary>
    public static class ServiceConfigResolver
    {
        /// <summary>
        /// Resolve valor diretamente do IConfiguration (simplificado)
        /// </summary>
        public static string GetConfigurationValue(
            string configKey,
            ConfigurationManager configuration,
            string? defaultValue = null,
            ILogger? logger = null)
        {
            // Apenas IConfiguration, pois as env vars já foram carregadas
            var configValue = configuration[configKey];

            if (!string.IsNullOrEmpty(configValue))
            {
                logger?.LogDebug("Config '{ConfigKey}' found: {Value}", configKey, configValue);
                return configValue;
            }

            // Usar valor padrão se não encontrou
            if (!string.IsNullOrEmpty(defaultValue))
            {
                logger?.LogDebug("Config '{ConfigKey}' using default value: {Value}", configKey, defaultValue);
                return defaultValue;
            }

            // Se não encontrou, exceção
            logger?.LogError("Configuration '{ConfigKey}' not found and no default provided", configKey);
            throw new InvalidOperationException($"Required configuration '{configKey}' not found in IConfiguration");
        }

        /// <summary>
        /// Determina se deve usar serviço externo baseado na configuração
        /// </summary>
        public static bool ShouldUseExternalService(
            ConfigurationManager configuration,
            string serviceKey,
            ILogger? logger = null)
        {
            var useExternal = bool.Parse(GetConfigurationValue(
                $"{serviceKey}:UseExternalService",
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