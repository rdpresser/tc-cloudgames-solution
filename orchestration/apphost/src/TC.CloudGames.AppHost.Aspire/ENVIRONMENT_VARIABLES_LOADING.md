# Environment Variables Loading - Aspire AppHost

Este documento explica como as variáveis de ambiente são carregadas de arquivos `.env` **ANTES** da criação do builder do Aspire, garantindo que estejam disponíveis no `IConfiguration`.

## ?? **Como Funciona**

### **1. Carregamento Antes do Builder**
As variáveis de ambiente são carregadas **antes** da criação do `DistributedApplication.CreateBuilder(args)`:

```csharp
// Configure environment variables from .env files BEFORE creating the builder
TC.CloudGames.AppHost.Aspire.Extensions.DistributedApplicationBuilderExtensions.LoadEnvironmentVariables();

var builder = DistributedApplication.CreateBuilder(args);
```

### **2. Detecção Automática de Ambiente**
O sistema detecta automaticamente o ambiente atual:

```csharp
var env = environment ?? Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? 
     Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Development";
```

### **3. Busca Automática da Raiz do Projeto**
O sistema encontra automaticamente a raiz do projeto procurando por:
- Arquivos `*.sln`
- Diretório `.git`
- Arquivos `.env` ou `.env.*`

### **4. Carregamento Hierárquico**
1. **Base**: `.env` (configurações comuns)
2. **Específico**: `.env.{environment}` (sobrescreve as do base)

## ?? **Estrutura de Arquivos**

### **Localização dos Arquivos**
```
src/TC.CloudGames.AppHost.Aspire/
??? .env           # Configurações base (todos os ambientes)
??? .env.development        # Configurações específicas para Development
??? .env.production      # Configurações específicas para Production
??? .env.staging         # Configurações específicas para Staging
??? Program.cs     # Chama LoadEnvironmentVariables() antes do builder
```

### **Exemplo: .env (Base)**
```env
# Configurações comuns para todos os ambientes
Database__UsersDbName=tc-cloudgames-users-db
Database__GamesDbName=tc-cloudgames-games-db
Database__PaymentsDbName=tc-cloudgames-payments-db
Database__Schema=public
Database__ConnectionTimeout=30

Cache__UsersInstanceName=tc-cloudgames-users-cache
Cache__GamesInstanceName=tc-cloudgames-games-cache
Cache__PaymentsInstanceName=tc-cloudgames-payments-cache

RabbitMq__UsersExchange=user.events
RabbitMq__GamesExchange=game.events
RabbitMq__PaymentsExchange=payment.events
```

### **Exemplo: .env.development**
```env
# Configurações específicas para Development (localhost)
Database__UseExternalService=false
Database__Host=localhost
Database__Port=5432
Database__User=postgres
Database__Password=postgres

Cache__UseExternalService=false
Cache__Host=localhost
Cache__Port=6379
Cache__Secure=false

MessageBroker__Type=RabbitMQ
RabbitMq__UseExternalService=false
RabbitMq__Host=localhost
RabbitMq__Port=5672

AZURITE_AUTO_START=true
ASPNETCORE_ENVIRONMENT=Development
```

### **Exemplo: .env.production**
```env
# Configurações específicas para Production (Azure)
Database__UseExternalService=true
Database__Host=prod-postgres.azure.com
Database__Port=5432

Cache__UseExternalService=true
Cache__Host=prod-redis.azure.com
Cache__Port=6380
Cache__Secure=true

MessageBroker__Type=AzureServiceBus
AzureServiceBus__UseExternalService=true

AZURITE_AUTO_START=false
ASPNETCORE_ENVIRONMENT=Production
```

## ?? **Benefícios da Abordagem**

### **1. ? Carregamento Garantido**
- Variables são carregadas **antes** do builder
- Disponíveis no `IConfiguration` desde o primeiro momento
- Sem dependência de timing de carregamento

### **2. ?? Configuração Simplificada**
- Um único ponto de entrada: `LoadEnvironmentVariables()`
- Detecção automática de ambiente e raiz do projeto
- Hierarquia clara: base ? específico do ambiente

### **3. ?? Logs Informativos**
```
?? Loading environment variables for: development
?? Project root: C:\Projects\tc-cloudgames-solution\orchestration\apphost\src\TC.CloudGames.AppHost.Aspire
? Loaded base .env from: C:\Projects\...\TC.CloudGames.AppHost.Aspire\.env
? Loaded development .env from: C:\Projects\...\TC.CloudGames.AppHost.Aspire\.env.development
?? Environment variables loaded and available for IConfiguration
```

### **4. ?? Flexibilidade**
- Funciona com qualquer ambiente (`Development`, `Production`, `Staging`, etc.)
- Pode ser chamado manualmente com parâmetros específicos
- Fallback para método original via extension method

## ??? **Como Usar**

### **1. Configuração Automática (Recomendado)**
```csharp
// Program.cs
TC.CloudGames.AppHost.Aspire.Extensions.DistributedApplicationBuilderExtensions.LoadEnvironmentVariables();
var builder = DistributedApplication.CreateBuilder(args);
```

### **2. Configuração Manual**
```csharp
// Especificar ambiente e/ou raiz do projeto manualmente
TC.CloudGames.AppHost.Aspire.Extensions.DistributedApplicationBuilderExtensions
    .LoadEnvironmentVariables("Production", @"C:\Projects\my-project\");
var builder = DistributedApplication.CreateBuilder(args);
```

### **3. Configuração via Extension Method (Alternativa)**
```csharp
// Se você não chamou LoadEnvironmentVariables() antes
var builder = DistributedApplication.CreateBuilder(args);
builder.ConfigureEnvironmentVariables(); // Carrega após criar o builder
```

## ?? **Variáveis de Ambiente Disponíveis**

Com o novo sistema, todas essas configurações estão disponíveis no `IConfiguration`:

### **Database**
- `Database__UseExternalService`
- `Database__Host`
- `Database__Port`
- `Database__UsersDbName` / `Database__GamesDbName` / `Database__PaymentsDbName`
- `Database__User` / `Database__Password`
- `Database__Schema`
- `Database__ConnectionTimeout`

### **Cache**
- `Cache__UseExternalService`
- `Cache__Host` / `Cache__Port` / `Cache__Secure`
- `Cache__UsersInstanceName` / `Cache__GamesInstanceName` / `Cache__PaymentsInstanceName`

### **Message Broker**
- `MessageBroker__Type`
- `RabbitMq__*` (configurações do RabbitMQ)
- `AzureServiceBus__*` (configurações do Azure Service Bus)

### **Grafana Cloud**
- `GrafanaCloud__OtelExporterOtlpEndpoint`
- `GrafanaCloud__OtelExporterOtlpProtocol`
- `GrafanaCloud__UsersOtelResourceAttributes` / etc.

### **Azurite**
- `AZURITE_AUTO_START`

## ?? **Fluxo de Execução**

```
1. Program.cs inicia
   ?
2. LoadEnvironmentVariables() é chamado
   ?
3. Sistema detecta ambiente atual
   ?
4. Sistema encontra raiz do projeto
   ?
5. Carrega .env (base)
   ?
6. Carrega .env.{environment} (específico)
   ?
7. Variables disponíveis via Environment.GetEnvironmentVariable()
   ?
8. DistributedApplication.CreateBuilder(args) é chamado
   ?
9. IConfiguration tem acesso a todas as variables
   ?
10. Registry e Services podem ler configurações normalmente
```

## ? **Resultado**

Agora você pode:
- ? **Configurar tudo via .env**: Database, Cache, MessageBroker, etc.
- ? **Ambiente específico**: `.env.development` vs `.env.production`
- ? **Simplificar código**: Menos `WithEnvironment()` desnecessários
- ? **Garantir carregamento**: Variables disponíveis desde o início
- ? **Manter segurança**: Secrets ainda via Aspire Parameters

**O sistema de configuração agora é mais robusto, flexível e fácil de usar!** ???