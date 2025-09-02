namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    public static class DistributedApplicationBuilderExtensions
    {
        /// <summary>
        /// Configura variáveis de ambiente a partir de arquivos .env para o Aspire AppHost.
        /// </summary>
        /// <param name="builder">IDistributedApplicationBuilder</param>
        /// <param name="projectRoot">Caminho raiz do projeto (opcional, será detectado automaticamente se não fornecido)</param>
        public static IDistributedApplicationBuilder ConfigureEnvironmentVariables(this IDistributedApplicationBuilder builder, string? projectRoot = null)
        {
            var environment = builder.Environment.EnvironmentName.ToLowerInvariant();
            var rootPath = projectRoot ?? FindProjectRoot() ?? Directory.GetCurrentDirectory();

            LoadEnvironmentFiles(rootPath, environment);

            return builder;
        }

        /// <summary>
        /// Carrega arquivos .env base e específicos do ambiente
        /// </summary>
        private static void LoadEnvironmentFiles(string projectRoot, string environment)
        {
            // Load base .env file first (if exists)
            var baseEnvFile = Path.Combine(projectRoot, ".env");
            if (File.Exists(baseEnvFile))
            {
                DotNetEnv.Env.Load(baseEnvFile);
                Console.WriteLine($"?? Loaded base .env from: {baseEnvFile}");
            }

            // Load environment-specific .env file (overrides base values)
            var envFile = Path.Combine(projectRoot, $".env.{environment}");
            if (File.Exists(envFile))
            {
                DotNetEnv.Env.Load(envFile);
                Console.WriteLine($"?? Loaded {environment} .env from: {envFile}");
            }
            else
            {
                Console.WriteLine($"?? Environment file not found: {envFile}");
            }
        }

        /// <summary>
        /// Encontra a raiz do projeto procurando por arquivos .sln, diretório .git ou arquivos .env
        /// </summary>
        private static string? FindProjectRoot()
        {
            var directory = new DirectoryInfo(Directory.GetCurrentDirectory());

            while (directory != null)
            {
                // Look for common project root indicators
                if (directory.GetFiles("*.sln").Length > 0 ||
                    directory.GetDirectories(".git").Length > 0 ||
                    HasEnvFiles(directory))
                {
                    return directory.FullName;
                }
                directory = directory.Parent;
            }

            return null;
        }

        /// <summary>
        /// Verifica se o diretório contém arquivos .env
        /// </summary>
        private static bool HasEnvFiles(DirectoryInfo directory)
        {
            return directory.GetFiles(".env").Length > 0 ||
                   directory.GetFiles(".env.*").Length > 0;
        }
    }
}