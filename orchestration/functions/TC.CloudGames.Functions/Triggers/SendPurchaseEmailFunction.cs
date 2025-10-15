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
        [ServiceBusTrigger("game.events-topic", "purchase-subscription", Connection = "AzureWebJobsServiceBus")] string messageBody)
    {
        _logger.LogInformation("🔔 Mensagem recebida no trigger SendPurchaseEmail: {Message}", messageBody);

        try
        {
            var purchase = JsonSerializer.Deserialize<UserPurchaseMessage>(messageBody);
            if (purchase == null || string.IsNullOrWhiteSpace(purchase.Email) || purchase.UserId == Guid.Empty || purchase.Amount == 0)
            {
                _logger.LogWarning("⚠️ Mensagem inválida ou sem email/userId/amount");
                return;
            }

            _logger.LogInformation("✅ Processando compra para usuário {UserId}, email {Email}, jogo {GameName}", 
                purchase.UserId, purchase.Email, purchase.GameName);

            await _sendGridService.SendPurchaseEmailAsync(purchase).ConfigureAwait(false);
            
            _logger.LogInformation("✅ Email de compra enviado com sucesso para {Email}", purchase.Email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Erro ao processar mensagem de compra: {Message}", messageBody);
            throw; // Re-throw para que o Service Bus possa lidar com retry/dead letter
        }
    }
}
