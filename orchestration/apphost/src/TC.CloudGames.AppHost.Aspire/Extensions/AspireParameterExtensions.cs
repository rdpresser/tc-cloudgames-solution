namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    public static class AspireParameterExtensions
    {
        /// <summary>
        /// Adiciona um parâmetro Aspire com múltiplos níveis de fallback:
        /// Environment Variable → IConfiguration → Secrets → Default
        /// </summary>
        public static ResolvedParameter AddResolvedParameter(
            this IDistributedApplicationBuilder builder,
            string parameterName,
            string configKey,
            string envVarName,
            string defaultValue,
            bool secret = false)
        {
            string resolvedValue =
                Environment.GetEnvironmentVariable(envVarName) ??
                builder.Configuration[configKey] ??
                defaultValue;

            var resource = builder.AddParameter(parameterName,
                valueGetter: () => resolvedValue,
                publishValueAsDefault: !secret,
                secret: secret);

            return new ResolvedParameter
            {
                ParameterName = parameterName,
                ConfigKey = configKey,
                EnvVarName = envVarName,
                Value = resolvedValue,
                Secret = secret,
                Resource = resource
            };
        }

        /// <summary>
        /// Injeta um parâmetro como variável de ambiente em um recurso Aspire.
        /// </summary>
        public static IResourceBuilder<T> WithParameterEnv<T>(
            this IResourceBuilder<T> builder,
            string envVarName,
            IResourceBuilder<ParameterResource> parameter)
            where T : IResourceWithEnvironment
        {
            return builder.WithEnvironment(envVarName, parameter);
        }

        public static IResourceBuilder<T> WithParameterEnv<T>(
            this IResourceBuilder<T> builder,
            string envVarName,
            ResolvedParameter parameter)
            where T : IResourceWithEnvironment
        {
            return builder.WithEnvironment(envVarName, parameter.Resource);
        }
    }
}