# TC Cloud Games - Microservices Solution

A modern cloud-native gaming platform built with microservices architecture, Azure infrastructure, and .NET Aspire orchestration.

## 🏗️ Architecture Overview

This solution follows a well-organized microservices architecture with clear separation of concerns:

```
tc-cloudgames-solution/
├── 🛠️ infrastructure/     # Infrastructure as Code
│   └── infra/             # Terraform files (Azure Container Apps, Key Vault, etc.)
├── 🚀 orchestration/      # Development environment orchestration  
│   └── apphost/           # .NET Aspire AppHost for local development
├── 🎯 services/           # Business microservices
│   ├── users/             # User management, authentication & access control
│   ├── games/             # Game management, sessions & scoring
│   └── payments/          # Payments, transactions & credits
├── 🧱 shared/             # Shared components
│   └── common/            # Shared Kernel (contracts, events, utilities)
├── 🔄 automation/         # CI/CD automation
│   └── pipelines/         # GitHub Actions workflows orchestrator
└── 📜 scripts/            # Solution automation scripts
    └── clone-repos.ps1    # Repository cloning script
```

## 📦 Repositories

| Repository | Alias | Category | Description |
|------------|-------|----------|-------------|
| `tc-cloudgames-infra` | `infra` | 🛠️ Infrastructure | Terraform IaC for Azure Container Apps, Key Vault, Managed Identity, DNS, ACR |
| `tc-cloudgames-apphost` | `apphost` | 🚀 Orchestration | .NET Aspire AppHost for local development environment orchestration |
| `tc-cloudgames-users` | `users` | 🎯 Services | User management microservice with authentication, access control & Event Sourcing |
| `tc-cloudgames-games` | `games` | 🎯 Services | Game management microservice for sessions, scoring & game flow logic |
| `tc-cloudgames-payments` | `payments` | 🎯 Services | Payment microservice for transactions, credits & financial provider integration |
| `tc-cloudgames-common` | `common` | 🧱 Shared | Shared Kernel with contracts, integration events, utilities & validators |
| `tc-cloudgames-pipelines` | `pipelines` | 🔄 Automation | GitHub Actions workflows orchestrator for centralized CI/CD |

## 🧩 Component Matrix

| Repository | 🌐 Infra | ⚙️ AppHost | 👤 Users | 🎮 Games | 💳 Payments | ♻️ Shared | 🔁 CI/CD |
|------------|:--------:|:----------:|:--------:|:--------:|:-----------:|:--------:|:--------:|
| `tc-cloudgames-infra` | ✅ | | | | | | ✅ |
| `tc-cloudgames-apphost` | | ✅ | ✅ | ✅ | ✅ | ✅ | |
| `tc-cloudgames-users` | | | ✅ | | | ✅ | ✅ |
| `tc-cloudgames-games` | | | | ✅ | | ✅ | ✅ |
| `tc-cloudgames-payments` | | | | | ✅ | ✅ | ✅ |
| `tc-cloudgames-common` | | | ✅ | ✅ | ✅ | ✅ | |
| `tc-cloudgames-pipelines` | ✅ | | | | | | ✅ |
| `tc-cloudgames-solution` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 🧩 Legend
- 🌐 **Infra** – Resource provisioning, networking, Key Vault, identity management
- ⚙️ **AppHost** – Local orchestration with .NET Aspire
- 👤 **Users** – Authentication and identity microservice
- 🎮 **Games** – Game logic and session microservice
- 💳 **Payments** – Financial microservice
- ♻️ **Shared** – Reusable code and contracts between microservices
- 🔁 **CI/CD** – Automation and deployment workflows

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have the following installed:

- [.NET 9 SDK](https://dotnet.microsoft.com/en-us/download) - For building and running .NET applications
- [Azure Developer CLI (azd)](https://aka.ms/azd-install) - For Azure deployment automation
- [Dapr CLI](https://docs.dapr.io/get-dapr/cli/install/) - For microservices communication
- [Docker Desktop](https://www.docker.com/) - For containerization
- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) - For infrastructure provisioning
- Azure subscription with appropriate permissions

### 1. Clone All Repositories

Use the provided PowerShell script to clone all repositories with organized folder structure:

```powershell
# Navigate to your development directory
cd C:\Projects

# Clone the solution repository
git clone https://github.com/rdpresser/tc-cloudgames-solution.git
cd tc-cloudgames-solution

# Run the automated cloning script
.\scripts\clone-repos.ps1
```

The script will create the following organized structure:
```
tc-cloudgames-solution/
├── infrastructure/infra/
├── orchestration/apphost/
├── services/
│   ├── users/
│   ├── games/
│   └── payments/
├── shared/common/
└── automation/pipelines/
```

### 2. Local Development with Aspire

```powershell
# Navigate to the AppHost project
cd orchestration/apphost

# Restore dependencies
dotnet restore

# Run the Aspire AppHost (starts all microservices locally)
dotnet run
```

This will start the Aspire dashboard and all configured microservices for local development.

### 3. Deploy to Azure

```powershell
# Navigate to infrastructure
cd infrastructure/infra

# Initialize and deploy infrastructure
terraform init
terraform plan
terraform apply

# Deploy applications using Azure Developer CLI
cd ../../
azd up
```

## 🛠️ Development Workflow

### Local Development
1. **Start dependencies**: Use Docker Compose or Dapr for external dependencies
2. **Run AppHost**: Execute the Aspire AppHost to orchestrate all microservices
3. **Develop**: Make changes to individual microservices
4. **Test**: Use the integrated testing approach with shared contracts

### CI/CD Pipeline
1. **Code changes**: Push to feature branches
2. **Automated testing**: GitHub Actions run tests and quality checks
3. **Infrastructure validation**: Terraform plans are validated
4. **Deployment**: Automatic deployment to staging/production environments

## 📚 Documentation

Each repository contains detailed documentation:

- **Infrastructure**: Terraform modules, Azure resource configuration
- **Services**: API documentation, domain models, event schemas
- **AppHost**: Local development setup, service configuration
- **Common**: Shared contracts, event definitions, utilities
- **Pipelines**: CI/CD workflow documentation

## 🔐 Security & Compliance

- **Authentication**: Azure Active Directory integration
- **Authorization**: Role-based access control (RBAC)
- **Secrets Management**: Azure Key Vault for sensitive data
- **Network Security**: Virtual networks, private endpoints
- **Monitoring**: Azure Application Insights, logging

## 🤝 Contributing

1. Fork the relevant repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the individual repository LICENSE files for details.

## 📞 Support

For questions or issues:
- Open an [issue](https://github.com/rdpresser/tc-cloudgames-solution/issues) in this repository
- Check individual repository documentation
- Review the troubleshooting guides in each service

---

**TC Cloud Games** - Building the future of cloud gaming with modern microservices architecture.
