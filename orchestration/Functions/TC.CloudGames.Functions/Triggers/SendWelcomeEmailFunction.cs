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
            _logger.LogInformation("Mensagem recebida no trigger: {Message}", messageBody);

            var user = JsonSerializer.Deserialize<EventContext<UserCreatedMessage>>(messageBody);
            if (user == null || string.IsNullOrWhiteSpace(user.EventData.Email))
            {
                _logger.LogWarning("Mensagem inválida ou sem email");
                return;
            }

            await _sendGridService.SendWelcomeEmailAsync(user.EventData).ConfigureAwait(false);
        }
    }
}
