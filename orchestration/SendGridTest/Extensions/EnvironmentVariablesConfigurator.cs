using System;
using System.IO;

namespace SendGridTest.Extensions;

/// <summary>
/// Utilitário para carregar variáveis de ambiente de arquivos .env em aplicações console / worker.
/// </summary>
public static class EnvironmentVariablesConfigurator
{
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
        var baseEnvFile = Path.Combine(projectRoot, ".env");
        if (File.Exists(baseEnvFile))
        {
            DotNetEnv.Env.Load(baseEnvFile);
            Console.WriteLine($"[env] Loaded base .env: {baseEnvFile}");
        }

        var envFile = Path.Combine(projectRoot, $".env.{environment}");
        if (File.Exists(envFile))
        {
            DotNetEnv.Env.Load(envFile);
            Console.WriteLine($"[env] Loaded environment override ({environment}): {envFile}");
        }
        else
        {
            Console.WriteLine($"[env] Environment file not found: {envFile}");
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
