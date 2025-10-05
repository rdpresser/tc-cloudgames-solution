# TC.CloudGames.Functions

Azure Functions project for handling email notifications.

## Setup Local Development

### 1. Environment Configuration

This project uses `local.settings.json` for local development configuration. This file contains sensitive information and is **NOT** committed to version control.

#### Steps to configure:

1. Copy the template file:
   ```bash
   cp local.settings.template.json local.settings.json
   ```

2. Edit `local.settings.json` and replace the placeholder values with your actual configuration:
   - `SERVICEBUS_CONNECTION`: Your Azure Service Bus connection string
   - `SENDGRID_API_KEY`: Your SendGrid API key
   - `SENDGRID_EMAIL_PURCHASE_TID`: SendGrid template ID for purchase emails
   - `SENDGRID_EMAIL_NEW_USER_TID`: SendGrid template ID for new user emails

### 2. Alternative: Using .env files

Alternatively, you can use `.env` files for configuration:

1. Create a `.env` file in the project root
2. Add your environment variables:
   ```
   SERVICEBUS_CONNECTION=your_connection_string_here
   SENDGRID_API_KEY=your_api_key_here
   SENDGRID_EMAIL_PURCHASE_TID=your_template_id_here
   SENDGRID_EMAIL_NEW_USER_TID=your_template_id_here
   ```

**Note:** The application will automatically load `.env` files only when `LOAD_ENV_FILES=true` is set in `local.settings.json`.

### 3. Running the Application

```bash
func start
```

## Deployment

For Azure deployment, configure the application settings in the Azure portal with the same keys used in `local.settings.json`.

## Security Notes

- **Never commit `local.settings.json`** - it's already in `.gitignore`
- **Never commit `.env` files** with real credentials - they're also in `.gitignore`
- Use Azure Key Vault for production secrets
- Use managed identities when possible