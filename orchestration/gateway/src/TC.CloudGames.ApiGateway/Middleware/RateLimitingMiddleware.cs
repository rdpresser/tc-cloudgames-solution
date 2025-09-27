using System.Threading.RateLimiting;

namespace TC.CloudGames.ApiGateway.Middleware;

public class RateLimitingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RateLimitingMiddleware> _logger;
    private readonly RateLimiter _rateLimiter;

    public RateLimitingMiddleware(RequestDelegate next, ILogger<RateLimitingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
        
        // Configure rate limiter
        _rateLimiter = new TokenBucketRateLimiter(new TokenBucketRateLimiterOptions
        {
            TokenLimit = 100,
            QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
            QueueLimit = 10,
            ReplenishmentPeriod = TimeSpan.FromMinutes(1),
            TokensPerPeriod = 100,
            AutoReplenishment = true
        });
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip rate limiting for health checks
        if (IsHealthCheck(context.Request.Path))
        {
            await _next(context);
            return;
        }

        var clientIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var endpoint = $"{context.Request.Method}:{context.Request.Path}";

        try
        {
            using var lease = await _rateLimiter.AcquireAsync();
            
            if (lease.IsAcquired)
            {
                _logger.LogDebug("✅ Rate limit OK for {ClientIp} - {Endpoint}", clientIp, endpoint);
                await _next(context);
            }
            else
            {
                _logger.LogWarning("🚫 Rate limit exceeded for {ClientIp} - {Endpoint}", clientIp, endpoint);
                
                context.Response.StatusCode = 429;
                context.Response.Headers["Retry-After"] = "60";
                await context.Response.WriteAsync("Rate limit exceeded. Please try again later.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Rate limiting error for {ClientIp} - {Endpoint}", clientIp, endpoint);
            // Continue with request if rate limiting fails
            await _next(context);
        }
    }

    private static bool IsHealthCheck(PathString path)
    {
        return path.StartsWithSegments("/health", StringComparison.OrdinalIgnoreCase);
    }
}

public static class RateLimitingMiddlewareExtensions
{
    public static IApplicationBuilder UseCustomRateLimiting(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<RateLimitingMiddleware>();
    }
}
