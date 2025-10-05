global using Microsoft.Azure.Functions.Worker;
global using Microsoft.Azure.Functions.Worker.Builder;
global using Microsoft.Extensions.DependencyInjection;
global using Microsoft.Extensions.Hosting;
global using Microsoft.Extensions.Logging;
global using SendGrid;
global using SendGrid.Helpers.Mail;
global using System.Text.Json;
global using TC.CloudGames.Functions.Abstractions;
global using TC.CloudGames.Functions.Extensions;
global using TC.CloudGames.Functions.Messages;
//**// REMARK: Required for functional and integration tests to work.
namespace TC.CloudGames.Functions
{
    public partial class Program;
}