namespace TC.CloudGames.Functions.Abstractions
{
    public class SendGridService : ISendGridService
    {
        private readonly ISendGridClient _sendGrid;
        private readonly ILogger _logger;

        public SendGridService(ISendGridClient sendGrid, ILoggerFactory loggerFactory)
        {
            _sendGrid = sendGrid ?? throw new ArgumentNullException(nameof(sendGrid));
            _logger = loggerFactory.CreateLogger<SendGridService>();
        }

        public async Task SendWelcomeEmailAsync(UserCreatedMessage userCreated)
        {
            var from = new EmailAddress("rodrigo.presser@gmail.com", "tccloudgames_mkt");
            var to = new EmailAddress(userCreated.Email, userCreated.Name);
            var tid = Environment.GetEnvironmentVariable("SENDGRID_EMAIL_NEW_USER_TID");

            var msg = MailHelper.CreateSingleTemplateEmail(
                from, to, tid,
                new
                {
                    subject = "Welcome to Our Service!"
                });

            var response = await _sendGrid.SendEmailAsync(msg);

            _logger.LogInformation("SendGrid Response: {StatusCode}", response.StatusCode);
            if (response.Body != null)
            {
                var body = await response.Body.ReadAsStringAsync();
                _logger.LogInformation("SendGrid Response body: {Body}", body);
            }
        }

        public async Task SendPurchaseEmailAsync(UserPurchaseMessage userPurchase)
        {
            var from = new EmailAddress("rodrigo.presser@gmail.com", "tccloudgames_mkt");
            var to = new EmailAddress(userPurchase.Email, userPurchase.Email);
            var tid = Environment.GetEnvironmentVariable("SENDGRID_EMAIL_PURCHASE_TID");

            var msg = MailHelper.CreateSingleTemplateEmail(
                from, to, tid,
                new
                {
                    subject = "Thank you for your purchase!"
                });

            var response = await _sendGrid.SendEmailAsync(msg);

            _logger.LogInformation("SendGrid Response: {StatusCode}", response.StatusCode);
            if (response.Body != null)
            {
                var body = await response.Body.ReadAsStringAsync();
                _logger.LogInformation("SendGrid Response body: {Body}", body);
            }
        }
    }
}
