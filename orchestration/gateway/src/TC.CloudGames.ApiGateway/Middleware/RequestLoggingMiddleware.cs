using Serilog;

namespace TC.CloudGames.ApiGateway.Middleware;

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var startTime = DateTime.UtcNow;
        var requestId = Guid.NewGuid().ToString("N")[..8];
        
        // Add request ID to context for tracing
        context.Items["RequestId"] = requestId;
        
        // Log request
        _logger.LogInformation(
            "🚀 [{RequestId}] {Method} {Path} from {RemoteIp} - UserAgent: {UserAgent}",
            requestId,
            context.Request.Method,
            context.Request.Path,
            context.Connection.RemoteIpAddress,
            context.Request.Headers.UserAgent.ToString());

        // Add request ID to response headers
        context.Response.Headers["X-Request-ID"] = requestId;

        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            var duration = DateTime.UtcNow - startTime;
            _logger.LogError(ex,
                "❌ [{RequestId}] Error processing {Method} {Path} - Duration: {Duration}ms",
                requestId,
                context.Request.Method,
                context.Request.Path,
                duration.TotalMilliseconds);
            throw;
        }

        var totalDuration = DateTime.UtcNow - startTime;
        _logger.LogInformation(
            "✅ [{RequestId}] {Method} {Path} - {StatusCode} - Duration: {Duration}ms",
            requestId,
            context.Request.Method,
            context.Request.Path,
            context.Response.StatusCode,
            totalDuration.TotalMilliseconds);
    }
}

public static class RequestLoggingMiddlewareExtensions
{
    public static IApplicationBuilder UseRequestLogging(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<RequestLoggingMiddleware>();
    }
}
