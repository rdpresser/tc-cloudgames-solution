using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Text;
using Yarp.ReverseProxy.Configuration;
using TC.CloudGames.ApiGateway.Middleware;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container
builder.Services.AddControllers();

// Configure JWT Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"] ?? throw new InvalidOperationException("JWT Key not configured")))
        };
    });

builder.Services.AddAuthorization();

// Configure CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Configure YARP Reverse Proxy
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// Add health checks
builder.Services.AddHealthChecks();

// Add rate limiting
builder.Services.AddRateLimiter();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

// Add middleware
app.UseSerilogRequestLogging();
app.UseCors("AllowAll");
app.UseRateLimiter();

// Add authentication and authorization
app.UseAuthentication();
app.UseAuthorization();

// Add custom middleware
app.UseRequestLogging();
app.UseCustomAuthentication();
app.UseCustomRateLimiting();

// Map health check endpoint
app.MapHealthChecks("/health");

// Map reverse proxy
app.MapReverseProxy();

// Map controllers
app.MapControllers();

// Add a simple status endpoint
app.MapGet("/", () => new
{
    Service = "TC Cloud Games API Gateway",
    Version = "1.0.0",
    Status = "Running",
    Timestamp = DateTime.UtcNow,
    Environment = app.Environment.EnvironmentName
});

Log.Information("🚀 API Gateway starting up...");

try
{
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "❌ API Gateway failed to start");
}
finally
{
    Log.CloseAndFlush();
}