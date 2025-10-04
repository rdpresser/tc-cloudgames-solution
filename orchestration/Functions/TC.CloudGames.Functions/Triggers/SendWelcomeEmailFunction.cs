using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using SendGrid;
using SendGrid.Helpers.Mail;
using System.Text.Json;
using TC.CloudGames.Functions.Messages;

namespace TC.CloudGames.Functions.Triggers
{
    public class SendWelcomeEmailFunction
    {
        private readonly SendGridClient _sendGrid;
        private readonly ILogger _logger;

        public SendWelcomeEmailFunction(SendGridClient sendGrid, ILoggerFactory loggerFactory)
        {
            _sendGrid = sendGrid;
            _logger = loggerFactory.CreateLogger<SendWelcomeEmailFunction>();
        }

        [Function("SendWelcomeEmail")]
        public async Task RunAsync(
            [ServiceBusTrigger("user.events-topic", "welcome-subscription", Connection = "ServiceBusConnection")] string messageBody)
        {
            _logger.LogInformation("Mensagem recebida no trigger: {Message}", messageBody);

            var user = JsonSerializer.Deserialize<UserCreatedMessage>(messageBody);
            if (user == null || string.IsNullOrWhiteSpace(user.Email))
            {
                _logger.LogWarning("Mensagem inválida ou sem email");
                return;
            }

            var sendGridMessage = new SendGridMessage()
            {
                From = new EmailAddress("no-reply@email.com", "TC Cloud Games"),
                Subject = "Bem-vindo ao TC Cloud Games!",
                PlainTextContent = $"Olá {user.Name}, bem-vindo ao TC Cloud Games!",
                HtmlContent = $"<p>Olá <strong>{user.Name}</strong>, bem-vindo ao TC Cloud Games!</p>"
            };
            sendGridMessage.AddTo(new EmailAddress(user.Email, user.Name));

            var response = await _sendGrid.SendEmailAsync(sendGridMessage);

            _logger.LogInformation("SendGrid Response: {StatusCode}", response.StatusCode);
        }
    }
}
