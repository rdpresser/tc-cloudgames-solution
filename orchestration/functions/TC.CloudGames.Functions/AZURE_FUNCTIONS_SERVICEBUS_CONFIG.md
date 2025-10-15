# Azure Functions - Configuração Adaptativa para Service Bus

Este documento explica como as Azure Functions foram configuradas para funcionar automaticamente tanto em ambiente de desenvolvimento (localhost) quanto em produção (Azure) sem necessidade de alterações no código.

## ?? **Como Funciona**

### **Detecção Automática de Ambiente**

O sistema detecta automaticamente o ambiente baseado na variável `DOTNET_ENVIRONMENT`:

```csharp
var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production";
```

### **Configuração por Ambiente**

#### **?? Development (Localhost)**
- **Detecta**: `DOTNET_ENVIRONMENT = "Development"`
- **Usa**: Connection String (`SERVICEBUS_CONNECTION`)
- **Configuração**: Connection string completa com chaves de acesso

```csharp
// Em Development (localhost), usa connection string
if (environment.Equals("Development", StringComparison.OrdinalIgnoreCase))
{
    services.AddAzureClients(builder =>
    {
        builder.AddServiceBusClient(connectionString);
    });
    
    // Configurar a variável para o trigger funcionar
    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus", connectionString);
}
```

#### **?? Production (Azure)**
- **Detecta**: `DOTNET_ENVIRONMENT != "Development"` (ou não definido)
- **Usa**: Namespace (`SERVICEBUS_NAMESPACE`) + Managed Identity
- **Configuração**: Autenticação automática via DefaultAzureCredential

```csharp
// Em produção (Azure), usa Managed Identity com namespace
else
{
    services.AddAzureClients(builder =>
    {
        builder.AddServiceBusClient(fullyQualifiedNamespace)
               .WithCredential(new DefaultAzureCredential());
    });
    
    // Configurar a variável para o trigger funcionar com namespace
    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus__fullyQualifiedNamespace", fullyQualifiedNamespace);
}
```

## ?? **Configuração por Ambiente**

### **Development (local.settings.json)**
```json
{
  "Values": {
    "DOTNET_ENVIRONMENT": "Development",
    "SERVICEBUS_CONNECTION": "Endpoint=sb://your-namespace.servicebus.windows.net/;SharedAccessKeyName=...",
    "SERVICEBUS_NAMESPACE": "your-namespace.servicebus.windows.net"
  }
}
```

### **Production (Azure App Settings)**
```
SERVICEBUS_NAMESPACE = your-namespace.servicebus.windows.net
// SERVICEBUS_CONNECTION não é necessário (Managed Identity)
// DOTNET_ENVIRONMENT não definido (padrão = Production)
```

## ?? **Triggers Genéricos**

As Functions agora usam uma configuração genérica que funciona em ambos ambientes:

```csharp
[ServiceBusTrigger("topic-name", "subscription-name", Connection = "AzureWebJobsServiceBus")]
```

**Antes (específico para ambiente):**
```csharp
// ? Específico para um ambiente
Connection = "SERVICEBUS_NAMESPACE"  // Só funciona no Azure
Connection = "SERVICEBUS_CONNECTION" // Só funciona em Development
```

**Depois (genérico):**
```csharp
// ? Funciona em ambos os ambientes
Connection = "AzureWebJobsServiceBus"
```

## ?? **Fluxo de Configuração**

1. **Startup da Function**
   ```
   ?? ServiceCollectionExtensions.AddDependencies()
   ```

2. **Detecção de Ambiente**
   ```
   ?? DOTNET_ENVIRONMENT = "Development" ? 
       ? Localhost (Connection String)
       ? Azure (Managed Identity)
   ```

3. **Configuração Automática**
   ```
   ?? Development: AzureWebJobsServiceBus = connection string
   ?? Production:  AzureWebJobsServiceBus__fullyQualifiedNamespace = namespace
   ```

4. **Triggers Funcionando**
   ```
   ? ServiceBusTrigger usa "AzureWebJobsServiceBus" em ambos ambientes
   ```

## ?? **Dependências Adicionadas**

Para suportar Managed Identity no Azure:

```xml
<PackageReference Include="Azure.Identity" Version="1.13.1" />
<PackageReference Include="Microsoft.Extensions.Azure" Version="1.13.0" />
```

## ?? **Benefícios**

1. **? Zero alterações de código** entre ambientes
2. **? Segurança aprimorada** com Managed Identity no Azure
3. **? Desenvolvimento simplificado** com connection string local
4. **? Configuração automática** baseada em ambiente
5. **? Logs informativos** sobre qual configuração está sendo usada

## ?? **Logs de Diagnóstico**

Durante a inicialização, você verá logs como:

**Development:**
```
?? Ambiente detectado: Development
?? [Development] Configurando Service Bus com Connection String
? Service Bus configurado com sucesso
```

**Production:**
```
?? Ambiente detectado: Production
?? [Production] Configurando Service Bus com Managed Identity: your-namespace.servicebus.windows.net
? Service Bus configurado com sucesso
```

## ??? **Como Usar**

### **1. Development (localhost)**
1. Configure `local.settings.json` com `DOTNET_ENVIRONMENT = "Development"`
2. Adicione `SERVICEBUS_CONNECTION` com sua connection string
3. Execute a Function - ela usará connection string automaticamente

### **2. Production (Azure)**
1. Configure no Azure App Settings apenas `SERVICEBUS_NAMESPACE`
2. Configure Managed Identity na Function App
3. Dê permissões à Managed Identity no Service Bus
4. Deploy - ela usará Managed Identity automaticamente

### **3. Triggers**
```csharp
[ServiceBusTrigger("topic", "subscription", Connection = "AzureWebJobsServiceBus")]
```

**Sempre use `Connection = "AzureWebJobsServiceBus"` - funciona em ambos ambientes!**

## ?? **Resultado**

Agora você pode:
- ? Desenvolver localmente com connection string
- ? Deployar no Azure com Managed Identity
- ? Sem alterar código entre ambientes
- ? Configuração automática e segura
- ? Logs claros sobre qual método está sendo usado

**Zero modificações de código necessárias entre Development e Production!** ??