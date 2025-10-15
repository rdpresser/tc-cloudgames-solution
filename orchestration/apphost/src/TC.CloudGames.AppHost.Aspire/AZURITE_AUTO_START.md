# Azurite Auto-Start Configuration

This document explains how Azurite can be automatically started with the Aspire AppHost using environment variables.

## ? What was implemented

### 1. **Environment Variable Detection**
The AppHost automatically detects when Azurite should be started through the `AZURITE_AUTO_START` environment variable:

```csharp
// Configure Azurite if AZURITE_AUTO_START is enabled
IResourceBuilder<IResource>? azurite = null;
if (Environment.GetEnvironmentVariable("AZURITE_AUTO_START") == "true")
{
    azurite = ServiceSetup.ConfigureAzurite(builder, logger);
}
```

### 2. **Simplified Azurite Configuration**
Azurite uses a simplified configuration that works reliably:

```csharp
/// <summary>
/// Configures the Azure Storage Emulator (Azurite)
/// </summary>
public static IResourceBuilder<IResource> ConfigureAzurite(
    IDistributedApplicationBuilder builder,
    ILogger? logger = null)
{
    logger?.LogInformation("??? Configuring Azure Storage Emulator (Azurite)");
    
    return builder.AddContainer("azurite", "mcr.microsoft.com/azure-storage/azurite")
        .WithBindMount("azurite-data", "/workspace")
        .WithEndpoint(port: 10000, targetPort: 10000, name: "blob")
        .WithEndpoint(port: 10001, targetPort: 10001, name: "queue")
        .WithEndpoint(port: 10002, targetPort: 10002, name: "table");
}
```

### 3. **Azure Functions Configuration**
When Azurite is available, Functions are automatically configured:

```csharp
// Configure Functions if Azurite is available
if (azurite != null)
{
    ProjectSetup.ConfigureFunctions(builder, registry, azurite, messageBroker, logger);
}
```

## ?? How to use

### 1. **Using Environment Variable**
Set the `AZURITE_AUTO_START` environment variable to enable Azurite:

```bash
# Set the environment variable
set AZURITE_AUTO_START=true
# or in PowerShell
$env:AZURITE_AUTO_START="true"

# Run the AppHost
dotnet run
```

### 2. **Using via launchSettings.json**
Add the environment variable to any profile in `launchSettings.json`:

```json
{
  "profiles": {
    "https": {
      "commandName": "Project",
      "launchBrowser": true,
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_ENVIRONMENT": "Development",
        "AZURITE_AUTO_START": "true"
      },
      "applicationUrl": "https://localhost:17176;http://localhost:15030"
    }
  }
}
```

## ?? Azurite - Configured Endpoints

When enabled, Azurite provides the following endpoints:

| Service | Endpoint | Port | Status |
|---------|----------|------|--------|
| **Blob Storage** | `http://localhost:10000` | 10000 | ? Functional |
| **Queue Storage** | `http://localhost:10001` | 10001 | ? Functional |
| **Table Storage** | `http://localhost:10002` | 10002 | ? Functional |

### Complete Connection String
```
DefaultEndpointsProtocol=http;
AccountName=devstoreaccount1;
AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;
BlobEndpoint=http://localhost:10000/devstoreaccount1;
QueueEndpoint=http://localhost:10001/devstoreaccount1;
TableEndpoint=http://localhost:10002/devstoreaccount1;
```

## ?? Execution Logs

When Azurite is enabled, you'll see:

```
??? Configuring Azure Storage Emulator (Azurite)
? Configuring Azure Functions
?? Configuring environment variables for Azure Functions
```

## ?? Benefits

1. **?? Simple Configuration**: Single environment variable controls Azurite
2. **?? Automatic Setup**: Functions automatically connect when Azurite is available
3. **?? Flexible**: Can be enabled/disabled per environment or profile
4. **?? Clean Code**: Simplified logic without complex profile detection
5. **?? Reliable**: Works consistently across different environments

## ????? Quick Test

To test quickly:

1. **Set environment variable and execute:**
```bash
set AZURITE_AUTO_START=true
dotnet run
```

2. **Check the logs** - should see:
```
??? Configuring Azure Storage Emulator (Azurite)
```

3. **Test the endpoints**:
   - http://localhost:10000 (Blob)
   - http://localhost:10001 (Queue)
   - http://localhost:10002 (Table)

4. **Confirm in Aspire Dashboard** that the `azurite` container is running without errors.

**Simple and effective!** ??