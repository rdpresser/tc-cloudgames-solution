namespace TC.CloudGames.Functions.Triggers
{
    public class SendWelcomeEmailFunction
    {
        private readonly ILogger _logger;
        private readonly ISendGridService _sendGridService;

        public SendWelcomeEmailFunction(ISendGridService sendGridService, ILoggerFactory loggerFactory)
        {
            _sendGridService = sendGridService ?? throw new ArgumentNullException(nameof(sendGridService));
            _logger = loggerFactory.CreateLogger<SendWelcomeEmailFunction>();
        }

        [Function("SendWelcomeEmail")]
        public async Task RunAsync(
            [ServiceBusTrigger("user.events-topic", "welcome-subscription", Connection = "SERVICEBUS_CONNECTION")] string messageBody)
        {
            _logger.LogInformation("🔔 Mensagem recebida no trigger SendWelcomeEmail: {Message}", messageBody);

            try
            {
                var user = JsonSerializer.Deserialize<EventContext<UserCreatedMessage>>(messageBody);
                if (user == null || string.IsNullOrWhiteSpace(user.EventData.Email))
                {
                    _logger.LogWarning("⚠️ Mensagem inválida ou sem email");
                    return;
                }

                _logger.LogInformation("✅ Processando boas-vindas para usuário {Email}", user.EventData.Email);

                await _sendGridService.SendWelcomeEmailAsync(user.EventData).ConfigureAwait(false);
                
                _logger.LogInformation("✅ Email de boas-vindas enviado com sucesso para {Email}", user.EventData.Email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Erro ao processar mensagem de boas-vindas: {Message}", messageBody);
                throw; // Re-throw para que o Service Bus possa lidar com retry/dead letter
            }
        }
    }
}
