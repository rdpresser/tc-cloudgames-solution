namespace TC.CloudGames.Functions.Triggers;

public class SendPurchaseEmailFunction
{
    private readonly ISendGridService _sendGridService;
    private readonly ILogger _logger;

    public SendPurchaseEmailFunction(ISendGridService sendGridService, ILoggerFactory loggerFactory)
    {
        _sendGridService = sendGridService ?? throw new ArgumentNullException(nameof(sendGridService));
        _logger = loggerFactory.CreateLogger<SendPurchaseEmailFunction>();
    }

    [Function("SendPurchaseEmail")]
    public async Task RunAsync(
        [ServiceBusTrigger("game.events-topic", "purchase-subscription", Connection = "SERVICEBUS_CONNECTION")] string messageBody)
    {
        _logger.LogInformation("Mensagem recebida no trigger: {Message}", messageBody);

        var purchase = JsonSerializer.Deserialize<UserPurchaseMessage>(messageBody);
        if (purchase == null || string.IsNullOrWhiteSpace(purchase.Email) || purchase.UserId == Guid.Empty || purchase.Amount == 0)
        {
            _logger.LogWarning("Mensagem inválida ou sem email/userId/amount");
            return;
        }

        await _sendGridService.SendPurchaseEmailAsync(purchase).ConfigureAwait(false);
    }
}
