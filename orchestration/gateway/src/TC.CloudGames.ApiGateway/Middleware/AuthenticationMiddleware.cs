using Microsoft.AspNetCore.Authentication.JwtBearer;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace TC.CloudGames.ApiGateway.Middleware;

public class AuthenticationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<AuthenticationMiddleware> _logger;
    private readonly IConfiguration _configuration;

    public AuthenticationMiddleware(RequestDelegate next, ILogger<AuthenticationMiddleware> logger, IConfiguration configuration)
    {
        _next = next;
        _logger = logger;
        _configuration = configuration;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip authentication for health checks and status endpoints
        if (IsPublicEndpoint(context.Request.Path))
        {
            await _next(context);
            return;
        }

        // Skip authentication for auth endpoints (login, register)
        if (IsAuthEndpoint(context.Request.Path))
        {
            await _next(context);
            return;
        }

        try
        {
            // Check if Authorization header exists
            if (!context.Request.Headers.ContainsKey("Authorization"))
            {
                _logger.LogWarning("🔒 Missing Authorization header for {Path}", context.Request.Path);
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Unauthorized: Missing Authorization header");
                return;
            }

            var authHeader = context.Request.Headers.Authorization.ToString();
            if (!authHeader.StartsWith("Bearer "))
            {
                _logger.LogWarning("🔒 Invalid Authorization header format for {Path}", context.Request.Path);
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Unauthorized: Invalid Authorization header format");
                return;
            }

            var token = authHeader.Substring("Bearer ".Length).Trim();
            
            // Validate token
            if (string.IsNullOrEmpty(token))
            {
                _logger.LogWarning("🔒 Empty token for {Path}", context.Request.Path);
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Unauthorized: Empty token");
                return;
            }

            // Add user information to context for downstream services
            try
            {
                var handler = new JwtSecurityTokenHandler();
                var jsonToken = handler.ReadJwtToken(token);
                
                // Extract user information
                var userId = jsonToken.Claims.FirstOrDefault(x => x.Type == "sub" || x.Type == "userId")?.Value;
                var userEmail = jsonToken.Claims.FirstOrDefault(x => x.Type == "email")?.Value;
                var userRole = jsonToken.Claims.FirstOrDefault(x => x.Type == "role")?.Value;

                if (!string.IsNullOrEmpty(userId))
                {
                    context.Items["UserId"] = userId;
                    context.Items["UserEmail"] = userEmail;
                    context.Items["UserRole"] = userRole;
                    
                    _logger.LogDebug("👤 User {UserId} ({UserEmail}) accessing {Path}", userId, userEmail, context.Request.Path);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "🔒 Invalid token format for {Path}", context.Request.Path);
                context.Response.StatusCode = 401;
                await context.Response.WriteAsync("Unauthorized: Invalid token");
                return;
            }

            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Authentication error for {Path}", context.Request.Path);
            context.Response.StatusCode = 500;
            await context.Response.WriteAsync("Internal Server Error");
        }
    }

    private static bool IsPublicEndpoint(PathString path)
    {
        var publicPaths = new[]
        {
            "/health",
            "/",
            "/status"
        };

        return publicPaths.Any(p => path.StartsWithSegments(p, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsAuthEndpoint(PathString path)
    {
        var authPaths = new[]
        {
            "/api/auth/login",
            "/api/auth/register",
            "/api/auth/refresh"
        };

        return authPaths.Any(p => path.StartsWithSegments(p, StringComparison.OrdinalIgnoreCase));
    }
}

public static class AuthenticationMiddlewareExtensions
{
    public static IApplicationBuilder UseCustomAuthentication(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<AuthenticationMiddleware>();
    }
}

