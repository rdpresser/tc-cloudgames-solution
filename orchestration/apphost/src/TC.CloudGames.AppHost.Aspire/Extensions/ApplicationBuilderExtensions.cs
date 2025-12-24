namespace TC.CloudGames.AppHost.Aspire.Extensions
{
    public static class ApplicationBuilderExtensions
    {
        /// <summary>
        /// Carrega variáveis de ambiente de arquivos .env ANTES da criação do builder.
        /// Deve ser chamado antes de DistributedApplication.CreateBuilder(args)
        /// </summary>
        /// <param name="environment">Nome do ambiente (opcional, será detectado automaticamente se não fornecido)</param>
        /// <param name="projectRoot">Caminho raiz do projeto (opcional, será detectado automaticamente se não fornecido)</param>
        public static void LoadEnvironmentVariables(string? environment = null, string? projectRoot = null)
        {
            var env = environment ?? Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ??
                     Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Development";
            var rootPath = projectRoot ?? FindProjectRoot() ?? Directory.GetCurrentDirectory();

            LoadEnvironmentFiles(rootPath, env.ToLowerInvariant());
        }

        /// <summary>
        /// Configura variáveis de ambiente a partir de arquivos .env para o Aspire AppHost.
        /// Use este método se você não chamou LoadEnvironmentVariables() antes de criar o builder.
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
            Console.WriteLine($"?? Loading environment variables for: {environment}");
            Console.WriteLine($"?? Project root: {projectRoot}");

            // Load base .env file first (if exists)
            var baseEnvFile = Path.Combine(projectRoot, ".env");
            if (File.Exists(baseEnvFile))
            {
                DotNetEnv.Env.Load(baseEnvFile);
                Console.WriteLine($"? Loaded base .env from: {baseEnvFile}");
            }
            else
            {
                Console.WriteLine($"?? Base .env file not found: {baseEnvFile}");
            }

            // Load environment-specific .env file (overrides base values)
            var envFile = Path.Combine(projectRoot, $".env.{environment}");
            if (File.Exists(envFile))
            {
                DotNetEnv.Env.Load(envFile);
                Console.WriteLine($"? Loaded {environment} .env from: {envFile}");
            }
            else
            {
                Console.WriteLine($"?? Environment-specific file not found: {envFile}");
            }

            Console.WriteLine("?? Environment variables loaded and available for IConfiguration");
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