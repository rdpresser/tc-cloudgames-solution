using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TC.CloudGames.Functions.Extensions
{
    /// <summary>
    /// Utilitário para carregar variáveis de ambiente de arquivos .env em aplicações console / worker.
    /// </summary>
    public static class EnvironmentVariablesConfigurator
    {
        private static bool _hasLoaded = false;

        /// <summary>
        /// Carrega arquivos .env e .env.{environment} apenas se estiver em ambiente local.
        /// Verifica a variável LOAD_ENV_FILES para determinar se deve carregar.
        /// Implementa singleton para evitar carregamentos múltiplos.
        /// </summary>
        /// <param name="projectRoot">Raiz do projeto (opcional). Se não informado será detectado subindo diretórios até achar um .sln, .git ou arquivos .env.</param>
        /// <param name="environment">Nome do ambiente (opcional). Se não informado usa DOTNET_ENVIRONMENT / ASPNETCORE_ENVIRONMENT / development.</param>
        public static void LoadFromEnvFilesIfLocal(string? projectRoot = null, string? environment = null)
        {
            if (_hasLoaded)
            {
                Console.WriteLine("[env] Environment files already loaded, skipping");
                return;
            }

            // Verifica se deve carregar arquivos .env (apenas em ambiente local)
            var loadEnvFiles = Environment.GetEnvironmentVariable("LOAD_ENV_FILES");
            
            if (string.IsNullOrEmpty(loadEnvFiles) || !bool.TryParse(loadEnvFiles, out var shouldLoad) || !shouldLoad)
            {
                Console.WriteLine("[env] Skipping .env files load - not in local environment or LOAD_ENV_FILES not set to true");
                return;
            }

            LoadFromEnvFiles(projectRoot, environment);
            _hasLoaded = true;
        }

        /// <summary>
        /// Carrega arquivos .env e .env.{environment}. O ambiente é detectado a partir de DOTNET_ENVIRONMENT ou ASPNETCORE_ENVIRONMENT.
        /// </summary>
        /// <param name="projectRoot">Raiz do projeto (opcional). Se não informado será detectado subindo diretórios até achar um .sln, .git ou arquivos .env.</param>
        /// <param name="environment">Nome do ambiente (opcional). Se não informado usa DOTNET_ENVIRONMENT / ASPNETCORE_ENVIRONMENT / development.</param>
        public static void LoadFromEnvFiles(string? projectRoot = null, string? environment = null)
        {
            var env = (environment ??
                       Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ??
                       Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ??
                       "development").ToLowerInvariant();

            var rootPath = projectRoot ?? FindProjectRoot() ?? Directory.GetCurrentDirectory();
            LoadEnvironmentFiles(rootPath, env);
        }

        private static void LoadEnvironmentFiles(string projectRoot, string environment)
        {
            var envFile = Path.Combine(projectRoot, $".env.{environment}");
            if (File.Exists(envFile))
            {
                DotNetEnv.Env.Load(envFile);
                Console.WriteLine($"[env] Loaded environment override ({environment}): {envFile}");
            }
            else
            {
                var baseEnvFile = Path.Combine(projectRoot, ".env");
                if (File.Exists(baseEnvFile))
                {
                    DotNetEnv.Env.Load(baseEnvFile);
                    Console.WriteLine($"[env] Loaded base .env: {baseEnvFile}");
                }
                else
                {
                    Console.WriteLine($"[env] Environment file not found: {envFile}");
                }
            }
        }

        private static string? FindProjectRoot()
        {
            var directory = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (directory != null)
            {
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

        private static bool HasEnvFiles(DirectoryInfo directory) =>
            directory.GetFiles(".env").Length > 0 || directory.GetFiles(".env.*").Length > 0;
    }

}
