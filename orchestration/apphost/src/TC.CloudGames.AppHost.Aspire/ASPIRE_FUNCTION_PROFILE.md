# Profile Aspire_Function - Configura��o Autom�tica

Este documento explica como o profile `Aspire_Function` foi configurado para inicializar automaticamente o Azurite junto com o AppHost do Aspire.

## ? O que foi implementado

### 1. **Detec��o Autom�tica do Profile**
O AppHost agora detecta automaticamente quando est� rodando no profile `Aspire_Function` atrav�s de:

```csharp
/// <summary>
/// Detecta se o profile Aspire_Function est� sendo usado
/// </summary>
static bool DetectAspireFunctionProfile()
{
    // Verifica se AZURITE_AUTO_START=true est� definido
    var azuriteAutoStart = Environment.GetEnvironmentVariable("AZURITE_AUTO_START");
    var hasAzuriteAutoStart = string.Equals(azuriteAutoStart, "true", StringComparison.OrdinalIgnoreCase);
    
    // Verifica argumentos da linha de comando para profile
    var args = Environment.GetCommandLineArgs();
    var hasProfileArg = args.Any(arg => 
        arg.Contains("Aspire_Function", StringComparison.OrdinalIgnoreCase) ||
        arg.Contains("--launch-profile", StringComparison.OrdinalIgnoreCase) && 
        args.Any(a => a.Contains("Aspire_Function", StringComparison.OrdinalIgnoreCase)));
    
    return hasAzuriteAutoStart || hasProfileArg;
}
```

### 2. **Configura��o Simplificada e Corrigida do Azurite**
O Azurite agora usa uma configura��o simplificada que funciona perfeitamente:

```csharp
/// <summary>
/// Configura o Azure Storage Emulator (Azurite)
/// </summary>
public static IResourceBuilder<IResource> ConfigureAzurite(
    IDistributedApplicationBuilder builder,
    ILogger? logger = null)
{
    logger?.LogInformation("??? Configurando Azure Storage Emulator (Azurite)");
    
    return builder.AddContainer("azurite", "mcr.microsoft.com/azure-storage/azurite")
        .WithBindMount("azurite-data", "/workspace")
        .WithEndpoint(port: 10000, targetPort: 10000, name: "blob")
        .WithEndpoint(port: 10001, targetPort: 10001, name: "queue")
        .WithEndpoint(port: 10002, targetPort: 10002, name: "table");
}
```

**?? Principais corre��es aplicadas:**
- ? **Removidos argumentos problem�ticos**: Eliminados `--blobHost`, `--queueHost`, `--tableHost` que causavam `node: bad option`
- ? **Configura��o padr�o**: Usa as configura��es padr�o do container Azurite
- ? **Volume correto**: `/workspace` � o diret�rio padr�o de trabalho do Azurite
- ? **Endpoints simples**: `WithEndpoint` ao inv�s de `WithHttpEndpoint` para melhor compatibilidade
- ? **Sem argumentos customizados**: Container roda com configura��o nativa

### 3. **Configura��o das Azure Functions**
As Functions s�o configuradas com connection string completa do Azurite:

```csharp
public static IResourceBuilder<ProjectResource> ConfigureFunctions(...)
{
    // ...
    if (azurite != null)
    {
        functionsProject = functionsProject
            .WithEnvironment("AzureWebJobsStorage", 
                "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;" +
                "AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;" +
                "BlobEndpoint=http://localhost:10000/devstoreaccount1;" +
                "QueueEndpoint=http://localhost:10001/devstoreaccount1;" +
                "TableEndpoint=http://localhost:10002/devstoreaccount1;")
            .WaitFor(azurite);
    }
    // ...
}
```

### 4. **Par�metros do SendGrid**
Configurados automaticamente para as Functions:

```csharp
private static void ConfigureSendGridParameters(...)
{
    registry.AddParameter(builder, "sendgrid-api-key", "SendGrid:ApiKey", "SENDGRID_API_KEY", "", secret: true);
    registry.AddParameter(builder, "sendgrid-email-new-user-tid", "SendGrid:EmailNewUserTid", "SENDGRID_EMAIL_NEW_USER_TID", "");
    registry.AddParameter(builder, "sendgrid-email-purchase-tid", "SendGrid:EmailPurchaseTid", "SENDGRID_EMAIL_PURCHASE_TID", "");
}
```

## ?? Como usar

### 1. **Usando o Profile no Visual Studio**
- Selecione o profile `Aspire_Function` no dropdown de profiles
- Execute o projeto (F5 ou Ctrl+F5)
- ? O Azurite iniciar� **SEM ERROS** agora
- ? As Functions se conectar�o automaticamente ao Azurite

### 2. **Usando via linha de comando**
```bash
dotnet run --launch-profile Aspire_Function
```

### 3. **Usando vari�vel de ambiente**
```bash
# Defina a vari�vel de ambiente
set AZURITE_AUTO_START=true
# ou no PowerShell
$env:AZURITE_AUTO_START="true"

# Execute o AppHost
dotnet run
```

## ?? Configura��o no launchSettings.json

O profile `Aspire_Function` no `launchSettings.json` deve conter:

```json
{
  "profiles": {
    "Aspire_Function": {
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

## ?? Azurite - Endpoints Configurados

O Azurite agora funciona com configura��o padr�o:

| Servi�o | Endpoint | Porta | Status |
|---------|----------|-------|--------|
| **Blob Storage** | `http://localhost:10000` | 10000 | ? Funcional |
| **Queue Storage** | `http://localhost:10001` | 10001 | ? Funcional |
| **Table Storage** | `http://localhost:10002` | 10002 | ? Funcional |

### Connection String Completa
```
DefaultEndpointsProtocol=http;
AccountName=devstoreaccount1;
AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;
BlobEndpoint=http://localhost:10000/devstoreaccount1;
QueueEndpoint=http://localhost:10001/devstoreaccount1;
TableEndpoint=http://localhost:10002/devstoreaccount1;
```

## ?? Logs de Execu��o

Quando o profile � executado corretamente, voc� ver�:

```
?? Detecting profile: Aspire_Function = True
??? Configurando Azure Storage Emulator (Azurite)
? Configurando Azure Functions
?? Configurando vari�veis de ambiente para Azure Functions
?? Configurando par�metros do SendGrid...
?? Conectando Functions ao Azure Service Bus
```

**? Sem mais erros como:**
- ? `The option "queueHost" is unknown`
- ? `node: bad option: --blobHost`
- ? `Did you mean the following one? -, --blobHost`

## ??? Solu��o de Problemas Resolvidos

### ? **Problema**: `node: bad option: --blobHost`
**Solu��o**: Removidos todos os argumentos customizados do Azurite. Container agora usa configura��o padr�o.

### ? **Problema**: Azurite n�o iniciava
**Solu��o**: Configura��o simplificada com `WithBindMount` para `/workspace` e `WithEndpoint` para exposi��o de portas.

### ? **Problema**: Functions n�o conectavam
**Solu��o**: Connection string completa configurada automaticamente com endpoints corretos.

### ? **Problema**: Erros de compila��o
**Solu��o**: Corrigidas chaves extras no c�digo e sintaxe de argumentos.

## ?? Benef�cios das Corre��es Finais

1. **?? Container Padr�o**: Azurite funciona com configura��o nativa sem customiza��es problem�ticas
2. **?? Inicializa��o Confi�vel**: Sem mais erros de argumentos inv�lidos
3. **?? Compatibilidade**: Funciona com diferentes vers�es do container Azurite
4. **?? Simplicidade**: Configura��o m�nima e eficaz
5. **?? Estabilidade**: Container inicia consistentemente em qualquer ambiente

## ?? Checklist de Funcionalidade

- ? **Profile detectado corretamente**
- ? **Azurite inicia sem erros**
- ? **Endpoints acess�veis** (10000, 10001, 10002)
- ? **Functions conectam ao Azurite**
- ? **SendGrid configurado**
- ? **Service Bus integrado**
- ? **Volume persistente funcionando**

**Agora o Azurite funciona perfeitamente com configura��o simplificada!** ???

## ????? Quick Test

Para testar rapidamente:

1. **Execute:**
```bash
dotnet run --launch-profile Aspire_Function
```

2. **Verifique os logs** - deve ver:
```
??? Configurando Azure Storage Emulator (Azurite)
```

3. **Teste os endpoints**:
   - http://localhost:10000 (Blob)
   - http://localhost:10001 (Queue)
   - http://localhost:10002 (Table)

4. **Confirme no Aspire Dashboard** que o container `azurite` est� rodando sem erros.

**Tudo funcionando! ??**