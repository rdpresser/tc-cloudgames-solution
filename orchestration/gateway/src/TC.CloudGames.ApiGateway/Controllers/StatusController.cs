using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using System.Reflection;

namespace TC.CloudGames.ApiGateway.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StatusController : ControllerBase
{
    private readonly ILogger<StatusController> _logger;
    private readonly IConfiguration _configuration;

    public StatusController(ILogger<StatusController> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    [HttpGet]
    public IActionResult GetStatus()
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            var version = assembly.GetName().Version?.ToString() ?? "1.0.0";
            var buildDate = System.IO.File.GetCreationTime(assembly.Location);

            var status = new
            {
                Service = "TC Cloud Games API Gateway",
                Version = version,
                BuildDate = buildDate,
                Status = "Running",
                Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown",
                Timestamp = DateTime.UtcNow,
                MachineName = Environment.MachineName,
                ProcessId = Environment.ProcessId,
                Uptime = DateTime.UtcNow - Process.GetCurrentProcess().StartTime.ToUniversalTime(),
                Configuration = new
                {
                    JwtIssuer = _configuration["Jwt:Issuer"],
                    JwtAudience = _configuration["Jwt:Audience"],
                    HasJwtKey = !string.IsNullOrEmpty(_configuration["Jwt:Key"])
                }
            };

            _logger.LogInformation("📊 Status requested - Service: {Service}, Version: {Version}", 
                status.Service, status.Version);

            return Ok(status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error getting status");
            return StatusCode(500, new { Error = "Internal Server Error", Message = ex.Message });
        }
    }

    [HttpGet("health")]
    public IActionResult GetHealth()
    {
        return Ok(new
        {
            Status = "Healthy",
            Timestamp = DateTime.UtcNow,
            Checks = new
            {
                Database = "Not Applicable",
                ExternalServices = "Not Applicable",
                Memory = GC.GetTotalMemory(false),
                Threads = Process.GetCurrentProcess().Threads.Count
            }
        });
    }

    [HttpGet("routes")]
    public IActionResult GetRoutes()
    {
        try
        {
            var routes = new
            {
                Gateway = new
                {
                    Status = "/api/status",
                    Health = "/api/status/health",
                    Routes = "/api/status/routes"
                },
                Microservices = new
                {
                    Games = new
                    {
                        BasePath = "/api/games",
                        Endpoints = new[]
                        {
                            "GET /api/games - List games",
                            "POST /api/games - Create game",
                            "GET /api/games/{id} - Get game by ID",
                            "GET /api/games/popular - Get popular games",
                            "POST /api/games/reindex - Reindex games",
                            "GET /api/games/search - Search games"
                        }
                    },
                    Users = new
                    {
                        BasePath = "/api/users",
                        Endpoints = new[]
                        {
                            "GET /api/users - List users",
                            "GET /api/users/{id} - Get user by ID",
                            "PUT /api/users/{id} - Update user",
                            "GET /api/users/email/{email} - Get user by email"
                        }
                    },
                    Auth = new
                    {
                        BasePath = "/api/auth",
                        Endpoints = new[]
                        {
                            "POST /api/auth/login - User login",
                            "POST /api/auth/register - User registration"
                        }
                    },
                    Payments = new
                    {
                        BasePath = "/api/payments",
                        Endpoints = new[]
                        {
                            "POST /api/payments - Process payment",
                            "GET /api/payments/{id} - Get payment by ID"
                        }
                    }
                }
            };

            return Ok(routes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error getting routes");
            return StatusCode(500, new { Error = "Internal Server Error", Message = ex.Message });
        }
    }
}
