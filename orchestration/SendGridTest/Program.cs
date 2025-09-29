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
            Execute().Wait();
        }

        static async Task Execute()
        {
            // Nome mais simples da variável de ambiente dentro do arquivo .env
            var apiKey = Environment.GetEnvironmentVariable("SENDGRID_KEY");
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                Console.WriteLine("SENDGRID_KEY não encontrada nas variáveis de ambiente.");
                return;
            }

            var client = new SendGridClient(apiKey);
            var from = new EmailAddress("test@example.com", "Example User");
            var subject = "Sending with SendGrid is Fun";
            var to = new EmailAddress("test@example.com", "Example User");
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