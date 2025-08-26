namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    public class ResolvedParameter
    {
        public string ParameterName { get; init; }
        public string ConfigKey { get; init; }
        public string EnvVarName { get; init; }
        public string Value { get; init; }
        public bool Secret { get; init; }
        public IResourceBuilder<ParameterResource> Resource { get; init; }
    }
}
