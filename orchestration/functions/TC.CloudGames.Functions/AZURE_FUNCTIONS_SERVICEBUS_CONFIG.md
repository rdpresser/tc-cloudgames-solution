# Azure Functions - Configura��o Adaptativa para Service Bus

Este documento explica como as Azure Functions foram configuradas para funcionar automaticamente tanto em ambiente de desenvolvimento (localhost) quanto em produ��o (Azure) sem necessidade de altera��es no c�digo.

## ?? **Como Funciona**

### **Detec��o Autom�tica de Ambiente**

O sistema detecta automaticamente o ambiente baseado na vari�vel `DOTNET_ENVIRONMENT`:

```csharp
var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production";
```

### **Configura��o por Ambiente**

#### **?? Development (Localhost)**
- **Detecta**: `DOTNET_ENVIRONMENT = "Development"`
- **Usa**: Connection String (`SERVICEBUS_CONNECTION`)
- **Configura��o**: Connection string completa com chaves de acesso

```csharp
// Em Development (localhost), usa connection string
if (environment.Equals("Development", StringComparison.OrdinalIgnoreCase))
{
    services.AddAzureClients(builder =>
    {
        builder.AddServiceBusClient(connectionString);
    });
    
    // Configurar a vari�vel para o trigger funcionar
    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus", connectionString);
}
```

#### **?? Production (Azure)**
- **Detecta**: `DOTNET_ENVIRONMENT != "Development"` (ou n�o definido)
- **Usa**: Namespace (`SERVICEBUS_NAMESPACE`) + Managed Identity
- **Configura��o**: Autentica��o autom�tica via DefaultAzureCredential

```csharp
// Em produ��o (Azure), usa Managed Identity com namespace
else
{
    services.AddAzureClients(builder =>
    {
        builder.AddServiceBusClient(fullyQualifiedNamespace)
               .WithCredential(new DefaultAzureCredential());
    });
    
    // Configurar a vari�vel para o trigger funcionar com namespace
    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus__fullyQualifiedNamespace", fullyQualifiedNamespace);
}
```

## ?? **Configura��o por Ambiente**

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
// SERVICEBUS_CONNECTION n�o � necess�rio (Managed Identity)
// DOTNET_ENVIRONMENT n�o definido (padr�o = Production)
```

## ?? **Triggers Gen�ricos**

As Functions agora usam uma configura��o gen�rica que funciona em ambos ambientes:

```csharp
[ServiceBusTrigger("topic-name", "subscription-name", Connection = "AzureWebJobsServiceBus")]
```

**Antes (espec�fico para ambiente):**
```csharp
// ? Espec�fico para um ambiente
Connection = "SERVICEBUS_NAMESPACE"  // S� funciona no Azure
Connection = "SERVICEBUS_CONNECTION" // S� funciona em Development
```

**Depois (gen�rico):**
```csharp
// ? Funciona em ambos os ambientes
Connection = "AzureWebJobsServiceBus"
```

## ?? **Fluxo de Configura��o**

1. **Startup da Function**
   ```
   ?? ServiceCollectionExtensions.AddDependencies()
   ```

2. **Detec��o de Ambiente**
   ```
   ?? DOTNET_ENVIRONMENT = "Development" ? 
       ? Localhost (Connection String)
       ? Azure (Managed Identity)
   ```

3. **Configura��o Autom�tica**
   ```
   ?? Development: AzureWebJobsServiceBus = connection string
   ?? Production:  AzureWebJobsServiceBus__fullyQualifiedNamespace = namespace
   ```

4. **Triggers Funcionando**
   ```
   ? ServiceBusTrigger usa "AzureWebJobsServiceBus" em ambos ambientes
   ```

## ?? **Depend�ncias Adicionadas**

Para suportar Managed Identity no Azure:

```xml
<PackageReference Include="Azure.Identity" Version="1.13.1" />
<PackageReference Include="Microsoft.Extensions.Azure" Version="1.13.0" />
```

## ?? **Benef�cios**

1. **? Zero altera��es de c�digo** entre ambientes
2. **? Seguran�a aprimorada** com Managed Identity no Azure
3. **? Desenvolvimento simplificado** com connection string local
4. **? Configura��o autom�tica** baseada em ambiente
5. **? Logs informativos** sobre qual configura��o est� sendo usada

## ?? **Logs de Diagn�stico**

Durante a inicializa��o, voc� ver� logs como:

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
3. Execute a Function - ela usar� connection string automaticamente

### **2. Production (Azure)**
1. Configure no Azure App Settings apenas `SERVICEBUS_NAMESPACE`
2. Configure Managed Identity na Function App
3. D� permiss�es � Managed Identity no Service Bus
4. Deploy - ela usar� Managed Identity automaticamente

### **3. Triggers**
```csharp
[ServiceBusTrigger("topic", "subscription", Connection = "AzureWebJobsServiceBus")]
```

**Sempre use `Connection = "AzureWebJobsServiceBus"` - funciona em ambos ambientes!**

## ?? **Resultado**

Agora voc� pode:
- ? Desenvolver localmente com connection string
- ? Deployar no Azure com Managed Identity
- ? Sem alterar c�digo entre ambientes
- ? Configura��o autom�tica e segura
- ? Logs claros sobre qual m�todo est� sendo usado

**Zero modifica��es de c�digo necess�rias entre Development e Production!** ??