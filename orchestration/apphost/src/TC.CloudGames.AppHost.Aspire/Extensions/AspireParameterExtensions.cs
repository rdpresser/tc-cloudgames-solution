namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    /// <summary>
    /// Extensões para injetar parâmetros como variáveis de ambiente em recursos Aspire.
    /// </summary>
    public static class AspireParameterExtensions
    {
        /// <summary>
        /// Injeta um parâmetro como variável de ambiente em um recurso Aspire.
        /// </summary>
        public static IResourceBuilder<T> WithParameterEnv<T>(
            this IResourceBuilder<T> builder,
            string envVarName,
            IResourceBuilder<ParameterResource>? parameter)
            where T : IResourceWithEnvironment
        {
            if (parameter != null)
            {
                return builder.WithEnvironment(envVarName, parameter);
            }
            return builder;
        }
    }
}