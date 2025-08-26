using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    public class ParameterRegistry
    {
        private readonly HashSet<ResolvedParameter> _parameters = new();

        public ResolvedParameter Add(
            IDistributedApplicationBuilder builder,
            string parameterName,
            string configKey,
            string envVarName,
            string defaultValue,
            bool secret = false)
        {
            var param = builder.AddResolvedParameter(
                parameterName: parameterName,
                configKey: configKey,
                envVarName: envVarName,
                defaultValue: defaultValue,
                secret: secret
            );

            _parameters.Add(param);
            return param;
        }

        public ResolvedParameter this[string parameterName]
        {
            get
            {
                var param = _parameters.FirstOrDefault(p => p.ParameterName == parameterName);
                return param ?? throw new KeyNotFoundException($"Parameter '{parameterName}' not found.");
            }
        }

        public void LogAll(IConfiguration config, ILogger logger)
        {
            foreach (var param in _parameters)
            {
                string source;
                string value = param.Value;

                if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable(param.EnvVarName)))
                    source = $"🌍 ENV ({param.EnvVarName})";
                else if (!string.IsNullOrEmpty(config[param.ConfigKey]))
                    source = $"📘 appsettings ({param.ConfigKey})";
                else
                    source = "🪫 default";

                if (param.Secret)
                    logger.LogInformation($"🔐 {param.ParameterName} resolved from {source}: ✔️ (secret)");
                else
                    logger.LogInformation($"🔎 {param.ParameterName} resolved from {source}: {value}");
            }
        }

        public IReadOnlyCollection<ResolvedParameter> Parameters => _parameters;

        public bool Contains(string parameterName) =>
            _parameters.Any(p => p.ParameterName == parameterName);
    }
}
