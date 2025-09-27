# TC Cloud Games API Gateway

Este é o API Gateway da plataforma TC Cloud Games, implementado usando YARP (Yet Another Reverse Proxy) e integrado com .NET Aspire.

## 🚀 Funcionalidades

### Roteamento
- **Games API**: `/api/games/*` → Games microservice
- **Users API**: `/api/users/*` → Users microservice  
- **Auth API**: `/api/auth/*` → Users microservice (autenticação)
- **Payments API**: `/api/payments/*` → Payments microservice

### Middleware
- **Request Logging**: Log detalhado de todas as requisições com Request ID
- **Authentication**: Validação de JWT tokens
- **Rate Limiting**: Controle de taxa de requisições
- **CORS**: Configuração de Cross-Origin Resource Sharing

### Endpoints do Gateway
- `GET /` - Status do gateway
- `GET /health` - Health check
- `GET /api/status` - Status detalhado
- `GET /api/status/health` - Health check detalhado
- `GET /api/status/routes` - Lista de rotas disponíveis

## 🏗️ Arquitetura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client App    │───▶│   API Gateway   │───▶│  Microservices  │
│                 │    │     (YARP)      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Middleware    │
                       │  - Auth         │
                       │  - Logging      │
                       │  - Rate Limit   │
                       └─────────────────┘
```

## 📁 Estrutura do Projeto

```
TC.CloudGames.ApiGateway/
├── Controllers/
│   └── StatusController.cs          # Endpoints de status
├── Middleware/
│   ├── AuthenticationMiddleware.cs  # Validação JWT
│   ├── RateLimitingMiddleware.cs    # Controle de taxa
│   └── RequestLoggingMiddleware.cs  # Logging de requisições
├── Program.cs                       # Configuração principal
├── appsettings.json                 # Configuração base
├── appsettings.Development.json     # Configuração desenvolvimento
└── appsettings.Production.json      # Configuração produção
```

## ⚙️ Configuração

### JWT Authentication
```json
{
  "Jwt": {
    "Key": "YourSuperSecretKeyThatIsAtLeast32CharactersLong!",
    "Issuer": "TC.CloudGames.ApiGateway",
    "Audience": "TC.CloudGames.Users"
  }
}
```

### YARP Reverse Proxy
```json
{
  "ReverseProxy": {
    "Routes": {
      "games-route": {
        "ClusterId": "games-cluster",
        "Match": {
          "Path": "/api/games/{**catch-all}"
        }
      }
    },
    "Clusters": {
      "games-cluster": {
        "Destinations": {
          "games-api": {
            "Address": "http://games-api/"
          }
        }
      }
    }
  }
}
```

## 🔧 Desenvolvimento

### Executar Localmente
```bash
cd orchestration/gateway/src/TC.CloudGames.ApiGateway
dotnet run
```

### Executar com Aspire
```bash
cd orchestration/apphost/src/TC.CloudGames.AppHost.Aspire
dotnet run
```

## 📊 Monitoramento

### Logs
- **Serilog** configurado para logging estruturado
- **Request ID** para rastreamento de requisições
- **Logs de autenticação** e **rate limiting**

### Métricas
- **Health checks** para monitoramento
- **Request/Response logging** com duração
- **Error tracking** com stack traces

## 🔒 Segurança

### Autenticação
- **JWT Bearer tokens** obrigatórios para endpoints protegidos
- **Validação de issuer/audience**
- **Extração de claims** para downstream services

### Rate Limiting
- **Token bucket algorithm**
- **100 requests/minute** por padrão
- **Queue limit** de 10 requisições

### CORS
- **AllowAll** policy para desenvolvimento
- **Configurável** para produção

## 🚀 Deploy

### Local (Aspire)
O gateway é automaticamente configurado e executado pelo Aspire AppHost.

### Produção
1. Configure as variáveis de ambiente
2. Ajuste as URLs dos microservices
3. Configure JWT secrets
4. Deploy como container ou serviço

## 📝 Exemplos de Uso

### Status do Gateway
```bash
curl http://localhost:5000/api/status
```

### Listar Rotas
```bash
curl http://localhost:5000/api/status/routes
```

### Acessar Games API
```bash
curl -H "Authorization: Bearer <token>" http://localhost:5000/api/games
```

### Health Check
```bash
curl http://localhost:5000/health
```

## 🔄 Integração com Microservices

O gateway automaticamente:
1. **Roteia** requisições para o microservice correto
2. **Adiciona** headers de contexto (User ID, Request ID)
3. **Valida** autenticação antes do roteamento
4. **Loga** todas as requisições e respostas
5. **Aplica** rate limiting

## 📈 Performance

- **YARP** oferece alta performance
- **Load balancing** RoundRobin configurado
- **Connection pooling** automático
- **Request/Response streaming** suportado

## 🛠️ Troubleshooting

### Problemas Comuns

1. **Erro 401 Unauthorized**
   - Verificar se o token JWT é válido
   - Verificar se o endpoint requer autenticação

2. **Erro 429 Too Many Requests**
   - Rate limit excedido
   - Aguardar ou ajustar configuração

3. **Erro 502 Bad Gateway**
   - Microservice não está disponível
   - Verificar health checks

### Logs Úteis
```bash
# Ver logs do gateway
docker logs tc-cloudgames-api-gateway

# Ver logs do Aspire
dotnet run --project orchestration/apphost/src/TC.CloudGames.AppHost.Aspire
```

## 🔮 Próximos Passos

- [ ] Implementar circuit breaker
- [ ] Adicionar métricas Prometheus
- [ ] Configurar SSL/TLS
- [ ] Implementar cache de respostas
- [ ] Adicionar suporte a WebSockets
- [ ] Implementar API versioning

