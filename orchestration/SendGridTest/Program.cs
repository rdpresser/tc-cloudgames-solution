using SendGrid;
using SendGrid.Helpers.Mail;
using SendGridTest.Extensions;

namespace SendGridTest
{
    internal class Example
    {
        private static void Main()
        {
            // Carrega variáveis de ambiente dos arquivos .env antes de qualquer uso
            EnvironmentVariablesConfigurator.LoadFromEnvFiles();

            // Nome mais simples da variável de ambiente dentro do arquivo .env
            var apiKey = Environment.GetEnvironmentVariable("SENDGRID_KEY");
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                Console.WriteLine("SENDGRID_KEY não encontrada nas variáveis de ambiente.");
                return;
            }

            //Execute(apiKey).Wait();
            //SendWelcomeEmailAsync(apiKey).Wait();
            //SendPurchaseEmailAsync(apiKey).Wait();
        }

        static async Task SendPurchaseEmailAsync(string apiKey)
        {
            var client = new SendGridClient(apiKey);
            var from = new EmailAddress("rodrigo.presser@gmail.com", "tccloudgames_mkt");
            var to = new EmailAddress("rodrigo.presser@gmail.com", "rodrigo.presser@gmail.com");
            var tid = Environment.GetEnvironmentVariable("SENDGRID_EMAIL_PURCHASE_TID");

            var msg = MailHelper.CreateSingleTemplateEmail(
                from,
                to,
                tid,
                new
                {
                    subject = "Thank you for your purchase!"
                });

            var response = await client.SendEmailAsync(msg);

            Console.WriteLine($"Status Code: {response.StatusCode}");
            if (response.Body != null)
            {
                var body = await response.Body.ReadAsStringAsync();
                Console.WriteLine(body);
            }
        }

        static async Task SendWelcomeEmailAsync(string apiKey)
        {
            var client = new SendGridClient(apiKey);
            var from = new EmailAddress("rodrigo.presser@gmail.com", "tccloudgames_mkt");
            var to = new EmailAddress("rodrigo.presser@gmail.com", "rodrigo.presser@gmail.com");
            var tid = Environment.GetEnvironmentVariable("SENDGRID_EMAIL_NEW_USER_TID");

            var msg = MailHelper.CreateSingleTemplateEmail(
                from,
                to,
                tid,
                new
                {
                    subject = "Welcome to Our Service!"
                });

            var response = await client.SendEmailAsync(msg);

            Console.WriteLine($"Status Code: {response.StatusCode}");
            if (response.Body != null)
            {
                var body = await response.Body.ReadAsStringAsync();
                Console.WriteLine(body);
            }
        }

        static async Task Execute(string apiKey)
        {
            var client = new SendGridClient(apiKey);
            var from = new EmailAddress("rodrigo.presser@gmail.com", "tccloudgames_mkt");
            var subject = "Sending with SendGrid is Fun";
            var to = new EmailAddress("rodrigo.presser@gmail.com", "rodrigo.presser@gmail.com");
            var plainTextContent = "and easy to do anywhere, even with C#";
            var htmlContent = "<strong>and easy to do anywhere, even with C#</strong>";
            var msg = MailHelper.CreateSingleEmail(from, to, subject, plainTextContent, htmlContent);
            var response = await client.SendEmailAsync(msg);

            Console.WriteLine($"Status Code: {response.StatusCode}");
            if (response.Body != null)
            {
                var body = await response.Body.ReadAsStringAsync();
                Console.WriteLine(body);
            }
        }
    }
}