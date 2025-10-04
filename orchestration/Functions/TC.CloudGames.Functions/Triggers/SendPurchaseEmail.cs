using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using SendGrid;
using SendGrid.Helpers.Mail;
using System.Text.Json;
using TC.CloudGames.Functions.Messages;

namespace TC.CloudGames.Functions.Triggers;

public class SendPurchaseEmailFunction
{
    private readonly SendGridClient _sendGrid;
    private readonly ILogger _logger;

    public SendPurchaseEmailFunction(SendGridClient sendGrid, ILoggerFactory loggerFactory)
    {
        _sendGrid = sendGrid;
        _logger = loggerFactory.CreateLogger<SendPurchaseEmailFunction>();
    }

    [Function("SendPurchaseEmail")]
    public async Task RunAsync(
        [ServiceBusTrigger("user.events-topic", "purchase-subscription", Connection = "ServiceBusConnection")] string messageBody)
    {
        _logger.LogInformation("Mensagem recebida no trigger: {Message}", messageBody);

        var purchase = JsonSerializer.Deserialize<UserPurchaseMessage>(messageBody);
        if (purchase == null || string.IsNullOrWhiteSpace(purchase.Email))
        {
            _logger.LogWarning("Mensagem inválida ou sem email");
            return;
        }

        var sendGridMessage = new SendGridMessage()
        {
            From = new EmailAddress("no-reply@email.com", "TC Cloud Games"),
            Subject = $"Confirmação da sua compra - {purchase.ProductName}",
            PlainTextContent = $"Olá! Confirmamos sua compra de {purchase.ProductName} no valor de R$ {purchase.Value}.",
            HtmlContent = $"<p>Olá,</p><p>Sua compra de <strong>{purchase.ProductName}</strong> no valor de <strong>R$ {purchase.Value}</strong> foi confirmada!</p><p>Obrigado por comprar conosco 🎮</p>"
        };
        sendGridMessage.AddTo(new EmailAddress(purchase.Email));

        var response = await _sendGrid.SendEmailAsync(sendGridMessage);

        _logger.LogInformation("SendGrid Response: {StatusCode}", response.StatusCode);
    }
}
