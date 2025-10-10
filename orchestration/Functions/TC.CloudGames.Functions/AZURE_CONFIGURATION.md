# Azure Functions Configuration Guide

## Para usar com System Managed Identity no Azure:

### Application Settings necess�rias no Azure Portal:

```
# Service Bus Configuration
SERVICEBUS_NAMESPACE=tc-cloudgames-dev.servicebus.windows.net
# OU use connection string para local/teste
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

1. A Azure Function j� tem System Managed Identity habilitada
2. O Terraform j� configurou as permiss�es "Azure Service Bus Data Owner"
3. Use SERVICEBUS_NAMESPACE em vez de SERVICEBUS_CONNECTION para Managed Identity

### Service Bus Topics e Subscriptions esperadas:

- **user.events-topic**
  - welcome-subscription
  
- **game.events-topic** 
  - purchase-subscription

### Debugging:

Se as fun��es n�o est�o sendo triggered:

1. Verifique se as mensagens est�o chegando nos t�picos corretos
2. Verifique se as subscriptions existem e t�m as regras de filtro corretas
3. Verifique os logs da Function App
4. Verifique se a Managed Identity tem as permiss�es corretas