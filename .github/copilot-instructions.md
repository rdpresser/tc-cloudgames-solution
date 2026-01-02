# TC Cloud Games - AI Agent Instructions

## 🏗️ Architecture Overview

This is a **microservices-based cloud gaming platform** with strict separation of concerns:

- **Mono-repo structure**: All infrastructure and orchestration in `tc-cloudgames-solution/`, services are independent repos
- **Service repositories**: `users/`, `games/`, `payments/` in `services/` folder (cloned via script)
- **Shared kernel**: `shared/common/` contains contracts, integration events, Wolverine configuration
- **Infrastructure**: Terraform for Azure (AKS, ACR, Key Vault, Service Bus, PostgreSQL, Redis)
- **Orchestration**: .NET Aspire AppHost (`orchestration/apphost/`) for local development
- **GitOps**: ArgoCD for production deployments on AKS

### Critical Workspace Layout
```
tc-cloudgames-solution/
├── services/{users,games,payments}/     # Independent microservices
├── shared/common/                        # Contracts, events, Wolverine setup
├── infrastructure/
│   ├── terraform/                        # Azure IaC
│   └── kubernetes/                       # K8s manifests + ArgoCD apps
├── orchestration/apphost/                # .NET Aspire for local dev
└── scripts/clone-repos.ps1               # Setup script
```

## 🎯 Microservices Architecture Patterns

### Hexagonal Architecture (Ports & Adapters)
All services follow this structure:
```
services/{service}/src/
├── Core/
│   ├── {Service}.Domain/       # Aggregates, ValueObjects, Domain Events
│   └── {Service}.Application/  # CQRS (Commands/Queries), UseCases, Ports
└── Adapters/
    ├── Inbound/
    │   └── {Service}.Api/      # FastEndpoints HTTP API
    └── Outbound/
        └── {Service}.Infrastructure/  # Marten, PostgreSQL, Redis, Messaging
```

### Technology Stack Per Service
- **API Framework**: **FastEndpoints** (NOT minimal APIs or controllers)
- **Messaging**: **Wolverine** with CQRS, Outbox pattern, and saga support
- **Event Sourcing**: **Marten** with PostgreSQL (Users service for audit trail)
- **CQRS**: **Marten** document database for read models (Games, Payments)
- **Persistence**: PostgreSQL (schema-per-service, NO Entity Framework - Marten only)
- **Caching**: Redis for distributed caching and sessions
- **Message Broker**: Azure Service Bus (prod), RabbitMQ (local dev)
- **Validation**: **FluentValidation** integrated with FastEndpoints

### CQRS + Event Sourcing
- **Commands**: Write operations in `Application/UseCases/Commands/` 
- **Queries**: Read operations in `Application/UseCases/Queries/`
- **Domain Events**: Captured in event-sourced aggregates (Marten event store)
- **Integration Events**: Cross-service events in `shared/common/src/TC.CloudGames.Contracts/Events/`
- **Outbox Pattern**: Wolverine + Marten ensure transactional event publishing

## 🔄 Inter-Service Communication

### Integration Events (Critical Pattern)
- **Contracts location**: `shared/common/src/TC.CloudGames.Contracts/Events/`
- **Event base class**: `BaseIntegrationEvent` with `Id`, `Timestamp`, `CorrelationId`
- **Naming convention**: `{Domain}{Action}IntegrationEvent` (e.g., `UserRegisteredIntegrationEvent`)
- **Publisher**: Service publishes via Wolverine to Azure Service Bus topics
- **Subscriber**: Services subscribe with Wolverine handlers in `Application/MessageBrokerHandlers/`

Example flow:
1. Games service publishes `GamePurchaseRequestedIntegrationEvent`
2. Payments service handles via `GamePurchaseRequestedHandler`
3. Payments publishes `PaymentApprovedIntegrationEvent`
4. Games handles via `PaymentApprovedHandler` → updates user library

### Service Bus Topology
- **Topics**: `user-events`, `game-events`, `payment-events`
- **Subscriptions**: Each service subscribes to relevant topics with SQL filters
- **Outbox Pattern**: Wolverine publishes events via Marten outbox for reliability
- **Local Dev**: RabbitMQ replaces Service Bus automatically via Wolverine

## 🔧 Development Workflows

### Local Development with Aspire
```powershell
cd orchestration/apphost
dotnet restore
dotnet run  # Starts all services, PostgreSQL, Redis, RabbitMQ
```
- Access Aspire dashboard at `http://localhost:15888` (or auto-opened URL)
- Services run with hot reload enabled
- Environment variables loaded from `.env` files in service roots

### Repository Cloning (First Time)
```powershell
cd tc-cloudgames-solution
.\scripts\clone-repos.ps1  # Clones all service repos into correct folders
```

### Building Services
Each service is self-contained:
```powershell
cd services/users  # or games, payments
dotnet restore TC.CloudGames.Users.sln
dotnet build --configuration Release
dotnet test  # Runs all test projects
```

### Docker Build Context
Dockerfiles expect root context:
```powershell
# From tc-cloudgames-solution root
docker build -f services/users/src/Adapters/Inbound/TC.CloudGames.Users.Api/Dockerfile -t users-api .
```

### CI/CD Pipeline Structure
- **Location**: `services/{service}/.github/workflows/{service}-build.yml`
- **Triggers**: Push to `main`, `develop`, `feature/*` branches with path filters
- **Multi-repo checkout**: Clones service repo + `shared/common` repo into workspace structure
- **Jobs**: Validate → Test (with coverage) → Build → Security Scan (Trivy) → Push to ACR
- **ACR**: Environment-based (`dev`/`prod`) via GitHub Environments

## ☸️ Kubernetes & Infrastructure

### Local K3D Cluster
```powershell
cd infrastructure/kubernetes/scripts
.\k3d-manager.ps1 create   # Creates cluster with ArgoCD, KEDA, Prometheus
.\k3d-manager.ps1 update-hosts  # Adds DNS entries (run as Admin)
.\k3d-manager.ps1 bootstrap     # Deploys apps via ArgoCD
```
- **Native Ingress**: Access via `http://argocd.local`, `http://cloudgames.local/{user,games,payments}`
- **ArgoCD creds**: `admin` / `Argo@123`

### Terraform (Azure Production)
```powershell
cd infrastructure/terraform/foundation
terraform init
terraform plan
terraform apply
```
- **Modules**: `aks_cluster`, `container_registry`, `key_vault`, `postgres`, `redis`, `service_bus`, `argocd`
- **State**: Stored in Azure Blob Storage
- **Resources**: AKS with Workload Identity, ACR, PostgreSQL Flexible, Redis Cache, Service Bus

### ArgoCD GitOps
- **Installation**: Via Kubernetes manifests (kubectl apply)
- **Manifests**: `infrastructure/kubernetes/manifests/application-*.yaml`
- **Kustomize**: Base configs in `base/`, overlays in `overlays/{dev,prod}/`
- **Deployment**: Services auto-sync from Git repository

## 📝 Code Conventions

### C# Project Standards
- **Target Framework**: `net9.0` (defined in `Directory.Build.props`)
- **Nullable Reference Types**: Enabled globally
- **Warnings as Errors**: Enforced (`TreatWarningsAsErrors=true`)
- **Code Analysis**: SonarAnalyzer.CSharp active in all projects

### Naming Conventions
- **Aggregates**: `{Entity}Aggregate` (e.g., `UserAggregate`, `GameAggregate`)
- **Value Objects**: Pascal case, no suffix (e.g., `Email`, `Price`, `Rating`)
- **Commands**: `{Action}{Entity}Command` (e.g., `RegisterUserCommand`)
- **Queries**: `Get{Entity}By{Criteria}Query` (e.g., `GetUserByEmailQuery`)
- **Endpoints**: `{Action}{Entity}Endpoint` (e.g., `RegisterUserEndpoint`)
- **Handlers**: `{Event}Handler` (e.g., `UserRegisteredHandler`)

### Testing Structure
```
test/TC.CloudGames.{Service}.Unit.Tests/
├── 1 - Unit.Testing/          # Domain & Application logic tests
├── 2 - Architecture.Testing/  # NetArchTest for hexagonal boundaries
├── 3 - Integration.Testing/   # Database, messaging integration
└── 4 - BDD.Testing/           # SpecFlow behavior tests (if present)
```

## 🚨 Common Pitfalls

1. **Shared Common Changes**: When modifying `shared/common/`, rebuild all services that depend on it
2. **Integration Events**: Always define in `shared/common/src/TC.CloudGames.Contracts/Events/`, never in service projects
3. **Database per Service**: Each service has its own PostgreSQL database—no direct cross-DB queries
4. **Message Handlers**: Must be in `Application/MessageBrokerHandlers/` with Wolverine's `[WolverineHandler]` or `IMessageHandler`
5. **Marten NOT Entity Framework**: Use Marten exclusively for persistence (Event Sourcing + Document DB)
6. **Dockerfile Context**: Always build from solution root, not service folder
7. **Outbox Pattern**: Wolverine + Marten guarantees event publishing reliability

## 🔍 Key Files Reference

- **Service Entry Point**: `services/{service}/src/Adapters/Inbound/TC.CloudGames.{Service}.Api/Program.cs`
- **Domain Aggregates**: `services/{service}/src/Core/TC.CloudGames.{Service}.Domain/Aggregates/`
- **Integration Events**: `shared/common/src/TC.CloudGames.Contracts/Events/{Domain}/`
- **Aspire AppHost**: `orchestration/apphost/src/TC.CloudGames.AppHost.Aspire/Program.cs`
- **K3D Manager**: `infrastructure/kubernetes/scripts/k3d-manager.ps1`
- **Terraform Modules**: `infrastructure/terraform/modules/{module}/main.tf`

## 💡 When Working On...

### Adding New Endpoints
1. Create endpoint class in `Adapters/Inbound/{Service}.Api/Endpoints/`
2. Inherit from `Endpoint<TRequest, TResponse>` (FastEndpoints)
3. Configure route in `Configure()` method
4. Implement `HandleAsync()` with command/query dispatch

### Adding Integration Events
1. Define contract in `shared/common/src/TC.CloudGames.Contracts/Events/{Domain}/`
2. Register in `TC.CloudGames.Messaging/Extensions/{Domain}EventsRegistrationExtensions.cs`
3. Publish via Wolverine `IMessageBus.PublishAsync()`
4. Handle in subscribing service's `Application/MessageBrokerHandlers/`

### Database Persistence (Marten)
Marten uses schema-as-code with automatic migrations:
- **Event Sourcing**: Users service persists all state changes as events
- **Document Store**: Games and Payments use Marten for document storage
- **Projections**: CQRS read models created from events
- **No Entity Framework**: Marten is the ONLY persistence mechanism

### Infrastructure Changes
1. Modify Terraform module in `infrastructure/terraform/modules/{module}/`
2. Update `foundation/main.tf` to use module
3. Run `terraform plan` and `terraform apply`
