# Azure Functions Configuration Guide

## To use with System Managed Identity in Azure:

### Required Application Settings in Azure Portal:

```
# Service Bus Configuration
SERVICEBUS_NAMESPACE=tc-cloudgames-dev.servicebus.windows.net
# OR use connection string for local/testing
SERVICEBUS_CONNECTION=Endpoint=sb://tc-cloudgames-dev.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=...

# SendGrid Configuration
SENDGRID_API_KEY=your_sendgrid_api_key
SENDGRID_EMAIL_PURCHASE_TID=d-71f2...
SENDGRID_EMAIL_NEW_USER_TID=d-f616...

# Azure Functions Runtime
FUNCTIONS_WORKER_RUNTIME=dotnet-isolated
FUNCTIONS_EXTENSION_VERSION=~4
```

### Managed Identity Setup:

1. The Azure Function already has System Managed Identity enabled
2. Terraform has already configured "Azure Service Bus Data Owner" permissions
3. Use SERVICEBUS_NAMESPACE instead of SERVICEBUS_CONNECTION for Managed Identity

### Expected Service Bus Topics and Subscriptions:

- **user.events-topic**
  - welcome-subscription
  
- **game.events-topic** 
  - purchase-subscription

### Debugging:

If functions are not being triggered:

1. Check if messages are reaching the correct topics
2. Check if subscriptions exist and have the correct filter rules
3. Check Function App logs
4. Check if Managed Identity has the correct permissions