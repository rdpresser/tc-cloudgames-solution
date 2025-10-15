# Azure Functions - Adaptive Service Bus Configuration

This document explains how Azure Functions have been configured to work automatically in both development (localhost) and production (Azure) environments without requiring code changes.

## ?? **How It Works**

### **Automatic Environment Detection**

The system automatically detects the environment based on the `DOTNET_ENVIRONMENT` variable:

```csharp
var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production";
```

### **Configuration by Environment**

#### **?? Development (Localhost)**
- **Detects**: `DOTNET_ENVIRONMENT = "Development"`
- **Uses**: Connection String (`SERVICEBUS_CONNECTION`)
- **Configuration**: Complete connection string with access keys

```csharp
// In Development (localhost), uses connection string
if (environment.Equals("Development", StringComparison.OrdinalIgnoreCase))
{
    services.AddAzureClients(builder =>
    {
        builder.AddServiceBusClient(connectionString);
    });
    
    // Configure the variable for trigger to work
    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus", connectionString);
}
```

#### **?? Production (Azure)**
- **Detects**: `DOTNET_ENVIRONMENT != "Development"` (or not defined)
- **Uses**: Namespace (`SERVICEBUS_NAMESPACE`) + Managed Identity
- **Configuration**: Automatic authentication via DefaultAzureCredential

```csharp
// In production (Azure), uses Managed Identity with namespace
else
{
    services.AddAzureClients(builder =>
    {
        builder.AddServiceBusClient(fullyQualifiedNamespace)
               .WithCredential(new DefaultAzureCredential());
    });
    
    // Configure the variable for trigger to work with namespace
    Environment.SetEnvironmentVariable("AzureWebJobsServiceBus__fullyQualifiedNamespace", fullyQualifiedNamespace);
}
```

## ?? **Configuration by Environment**

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
// SERVICEBUS_CONNECTION is not needed (Managed Identity)
// DOTNET_ENVIRONMENT not defined (default = Production)
```

## ?? **Generic Triggers**

Functions now use a generic configuration that works in both environments:

```csharp
[ServiceBusTrigger("topic-name", "subscription-name", Connection = "AzureWebJobsServiceBus")]
```

**Before (environment-specific):**
```csharp
// ? Environment-specific
Connection = "SERVICEBUS_NAMESPACE"  // Only works in Azure
Connection = "SERVICEBUS_CONNECTION" // Only works in Development
```

**After (generic):**
```csharp
// ? Works in both environments
Connection = "AzureWebJobsServiceBus"
```

## ?? **Configuration Flow**

1. **Function Startup**
   ```
   ?? ServiceCollectionExtensions.AddDependencies()
   ```

2. **Environment Detection**
   ```
   ?? DOTNET_ENVIRONMENT = "Development" ? 
       ? Localhost (Connection String)
       ? Azure (Managed Identity)
   ```

3. **Automatic Configuration**
   ```
   ?? Development: AzureWebJobsServiceBus = connection string
   ?? Production:  AzureWebJobsServiceBus__fullyQualifiedNamespace = namespace
   ```

4. **Triggers Working**
   ```
   ? ServiceBusTrigger uses "AzureWebJobsServiceBus" in both environments
   ```

## ?? **Required Dependencies**

To support Managed Identity in Azure, the following packages are used:

```xml
<!-- Azure Functions Runtime -->
<PackageReference Include="Microsoft.Azure.Functions.Worker" Version="2.1.0" />
<PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.24.0" />
<PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="2.0.5" />

<!-- Azure Identity and Extensions -->
<PackageReference Include="Azure.Identity" Version="1.17.0" />
<PackageReference Include="Microsoft.Extensions.Azure" Version="1.13.0" />

<!-- SendGrid (for email functionality) -->
<PackageReference Include="SendGrid" Version="9.29.3" />
<PackageReference Include="SendGrid.Extensions.DependencyInjection" Version="1.0.1" />

<!-- Additional Tools -->
<PackageReference Include="DotNetEnv" Version="3.1.1" />
<PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.23.0" />
```

## ?? **Benefits**

1. **? Zero code changes** between environments
2. **? Enhanced security** with Managed Identity in Azure
3. **? Simplified development** with local connection string
4. **? Automatic configuration** based on environment
5. **? Informative logs** about which configuration is being used

## ?? **Diagnostic Logs**

During initialization, you'll see logs like:

**Development:**
```
?? Environment detected: Development
?? [Development] Configuring Service Bus with Connection String
? Service Bus configured successfully
```

**Production:**
```
?? Environment detected: Production
?? [Production] Configuring Service Bus with Managed Identity: your-namespace.servicebus.windows.net
? Service Bus configured successfully
```

## ??? **How to Use**

### **1. Development (localhost)**
1. Configure `local.settings.json` with `DOTNET_ENVIRONMENT = "Development"`
2. Add `SERVICEBUS_CONNECTION` with your connection string
3. Run the Function - it will use connection string automatically

### **2. Production (Azure)**
1. Configure only `SERVICEBUS_NAMESPACE` in Azure App Settings
2. Configure Managed Identity in the Function App
3. Grant permissions to Managed Identity in Service Bus
4. Deploy - it will use Managed Identity automatically

### **3. Triggers**
```csharp
[ServiceBusTrigger("topic", "subscription", Connection = "AzureWebJobsServiceBus")]
```

**Always use `Connection = "AzureWebJobsServiceBus"` - works in both environments!**

## ?? **Result**

Now you can:
- ? Develop locally with connection string
- ? Deploy to Azure with Managed Identity
- ? No code changes between environments
- ? Automatic and secure configuration
- ? Clear logs about which method is being used

**Zero code modifications needed between Development and Production!** ??