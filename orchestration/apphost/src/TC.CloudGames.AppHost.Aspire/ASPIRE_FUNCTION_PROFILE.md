# Profile Aspire_Function - Configuração Automática

Este documento explica como o profile `Aspire_Function` foi configurado para inicializar automaticamente o Azurite junto com o AppHost do Aspire.

## ? O que foi implementado

### 1. **Detecção Automática do Profile**
O AppHost agora detecta automaticamente quando está rodando no profile `Aspire_Function` através de:

```csharp
/// <summary>
/// Detecta se o profile Aspire_Function está sendo usado
/// </summary>
static bool DetectAspireFunctionProfile()
{
    // Verifica se AZURITE_AUTO_START=true está definido
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

### 2. **Configuração Simplificada e Corrigida do Azurite**
O Azurite agora usa uma configuração simplificada que funciona perfeitamente:

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

**?? Principais correções aplicadas:**
- ? **Removidos argumentos problemáticos**: Eliminados `--blobHost`, `--queueHost`, `--tableHost` que causavam `node: bad option`
- ? **Configuração padrão**: Usa as configurações padrão do container Azurite
- ? **Volume correto**: `/workspace` é o diretório padrão de trabalho do Azurite
- ? **Endpoints simples**: `WithEndpoint` ao invés de `WithHttpEndpoint` para melhor compatibilidade
- ? **Sem argumentos customizados**: Container roda com configuração nativa

### 3. **Configuração das Azure Functions**
As Functions são configuradas com connection string completa do Azurite:

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

### 4. **Parâmetros do SendGrid**
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
- ? O Azurite iniciará **SEM ERROS** agora
- ? As Functions se conectarão automaticamente ao Azurite

### 2. **Usando via linha de comando**
```bash
dotnet run --launch-profile Aspire_Function
```

### 3. **Usando variável de ambiente**
```bash
# Defina a variável de ambiente
set AZURITE_AUTO_START=true
# ou no PowerShell
$env:AZURITE_AUTO_START="true"

# Execute o AppHost
dotnet run
```

## ?? Configuração no launchSettings.json

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

O Azurite agora funciona com configuração padrão:

| Serviço | Endpoint | Porta | Status |
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

## ?? Logs de Execução

Quando o profile é executado corretamente, você verá:

```
?? Detecting profile: Aspire_Function = True
??? Configurando Azure Storage Emulator (Azurite)
? Configurando Azure Functions
?? Configurando variáveis de ambiente para Azure Functions
?? Configurando parâmetros do SendGrid...
?? Conectando Functions ao Azure Service Bus
```

**? Sem mais erros como:**
- ? `The option "queueHost" is unknown`
- ? `node: bad option: --blobHost`
- ? `Did you mean the following one? -, --blobHost`

## ??? Solução de Problemas Resolvidos

### ? **Problema**: `node: bad option: --blobHost`
**Solução**: Removidos todos os argumentos customizados do Azurite. Container agora usa configuração padrão.

### ? **Problema**: Azurite não iniciava
**Solução**: Configuração simplificada com `WithBindMount` para `/workspace` e `WithEndpoint` para exposição de portas.

### ? **Problema**: Functions não conectavam
**Solução**: Connection string completa configurada automaticamente com endpoints corretos.

### ? **Problema**: Erros de compilação
**Solução**: Corrigidas chaves extras no código e sintaxe de argumentos.

## ?? Benefícios das Correções Finais

1. **?? Container Padrão**: Azurite funciona com configuração nativa sem customizações problemáticas
2. **?? Inicialização Confiável**: Sem mais erros de argumentos inválidos
3. **?? Compatibilidade**: Funciona com diferentes versões do container Azurite
4. **?? Simplicidade**: Configuração mínima e eficaz
5. **?? Estabilidade**: Container inicia consistentemente em qualquer ambiente

## ?? Checklist de Funcionalidade

- ? **Profile detectado corretamente**
- ? **Azurite inicia sem erros**
- ? **Endpoints acessíveis** (10000, 10001, 10002)
- ? **Functions conectam ao Azurite**
- ? **SendGrid configurado**
- ? **Service Bus integrado**
- ? **Volume persistente funcionando**

**Agora o Azurite funciona perfeitamente com configuração simplificada!** ???

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

4. **Confirme no Aspire Dashboard** que o container `azurite` está rodando sem erros.

**Tudo funcionando! ??**