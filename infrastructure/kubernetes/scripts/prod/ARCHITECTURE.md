# TC CloudGames - Infrastructure Scripts Architecture

## 📐 Architecture Overview

This document describes the modular architecture of the Kubernetes infrastructure management scripts.

## 🎯 Design Principles

1. **DRY (Don't Repeat Yourself)**: Scripts are reusable standalone components
2. **Modularity**: Each component can be installed/managed independently
3. **Idempotency**: All scripts can be run multiple times safely
4. **Orchestration**: Complete setup script orchestrates individual components
5. **User-Friendly**: Interactive menu with visual status indicators

## 📁 File Structure

```
infrastructure/kubernetes/scripts/prod/
├── aks-manager.ps1                      # Main orchestrator with interactive menu
├── setup-complete-infrastructure.ps1    # Complete setup workflow (calls standalone scripts)
│
├── install-nginx-ingress.ps1           # NGINX Ingress Controller (standalone)
├── install-external-secrets.ps1        # External Secrets Operator (standalone)
├── install-grafana-agent.ps1           # Grafana Agent (standalone)
├── install-argocd-aks.ps1             # ArgoCD (standalone)
│
├── setup-eso-workload-identity.ps1    # ESO + Workload Identity configuration
├── build-push-acr.ps1                 # Build and push Docker images
└── ARCHITECTURE.md                     # This file
```

## 🔄 Script Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                      aks-manager.ps1                         │
│                   (Main Entry Point)                         │
│                                                              │
│  • Interactive menu with status indicators                  │
│  • Individual component installation                        │
│  • Complete setup orchestration                             │
│  • Command-line interface                                   │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ├─────► install-nginx-ingress.ps1
                   │       • Helm chart installation
                   │       • LoadBalancer IP assignment
                   │       • -Force for reinstall
                   │
                   ├─────► install-external-secrets.ps1
                   │       • CRDs installation
                   │       • ESO operator setup
                   │       • -Force for reinstall
                   │
                   ├─────► install-grafana-agent.ps1
                   │       • Metrics collection
                   │       • Flow mode configuration
                   │       • -Force for reinstall
                   │
                   ├─────► install-argocd-aks.ps1
                   │       • ArgoCD installation
                   │       • LoadBalancer configuration
                   │
                   ├─────► setup-eso-workload-identity.ps1
                   │       • Azure Managed Identity
                   │       • Federated credentials
                   │       • ClusterSecretStore
                   │
                   └─────► setup-complete-infrastructure.ps1
                           • Orchestrates all components
                           • Terraform integration
                           • Post-deployment validation
```

## 🔧 Component Scripts

### 1. install-nginx-ingress.ps1
**Purpose**: Install NGINX Ingress Controller

**Features**:
- ✅ Idempotent (upgrade in-place by default)
- ✅ `-Force` parameter for complete reinstall
- ✅ LoadBalancer IP detection and reporting
- ✅ Production-ready resource limits
- ✅ Health probe configuration

**Usage**:
```powershell
# Standard installation/upgrade
.\install-nginx-ingress.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name"

# Force reinstall
.\install-nginx-ingress.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name" -Force
```

### 2. install-external-secrets.ps1
**Purpose**: Install External Secrets Operator

**Features**:
- ✅ Idempotent (upgrade in-place by default)
- ✅ `-Force` parameter for complete reinstall
- ✅ CRDs installation
- ✅ Production-ready resource limits
- ✅ Webhook configuration

**Usage**:
```powershell
# Standard installation/upgrade
.\install-external-secrets.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name"

# Force reinstall
.\install-external-secrets.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name" -Force
```

### 3. install-grafana-agent.ps1
**Purpose**: Install Grafana Agent for metrics collection

**Features**:
- ✅ Idempotent (upgrade in-place by default)
- ✅ `-Force` parameter for complete reinstall
- ✅ Flow mode configuration
- ✅ Kubernetes discovery (pods, nodes, services)
- ✅ Prometheus-compatible scraping

**Usage**:
```powershell
# Standard installation/upgrade
.\install-grafana-agent.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name"

# Force reinstall
.\install-grafana-agent.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name" -Force
```

### 4. setup-eso-workload-identity.ps1
**Purpose**: Configure Workload Identity for ESO

**Features**:
- ✅ Azure Managed Identity creation
- ✅ Federated credentials with OIDC
- ✅ Key Vault RBAC assignments
- ✅ Service Bus RBAC assignments
- ✅ ServiceAccount annotations (with tenant-id)
- ✅ ClusterSecretStore creation

**Critical**: Includes `azure.workload.identity/tenant-id` annotation (required for WorkloadIdentity auth)

**Usage**:
```powershell
.\setup-eso-workload-identity.ps1 `
    -ResourceGroup "rg-name" `
    -ClusterName "aks-name" `
    -KeyVaultName "kv-name"
```

## 🎛️ Orchestrator: setup-complete-infrastructure.ps1

**Purpose**: Complete post-Terraform infrastructure setup

**Workflow** (9 steps):
1. ✅ Connect to AKS cluster
2. ✅ Install NGINX Ingress (calls `install-nginx-ingress.ps1`)
3. ✅ Get LoadBalancer IP
4. ✅ Update Terraform variables
5. ✅ Re-run Terraform to update APIM backends
6. ✅ Install External Secrets Operator (calls `install-external-secrets.ps1`)
7. ✅ Configure Workload Identity (calls `setup-eso-workload-identity.ps1`)
8. ✅ (Optional) Install Grafana Agent (calls `install-grafana-agent.ps1`)
9. ✅ Deploy applications via Kustomize

**Features**:
- ✅ Modular: Calls standalone scripts (DRY)
- ✅ `-Force`: Pass to all component installers
- ✅ `-SkipNginx`: Skip NGINX installation
- ✅ `-SkipGrafana`: Skip Grafana Agent
- ✅ `-SkipDeploy`: Skip Kustomize deployment
- ✅ Interactive prompts with clear explanations

**Usage**:
```powershell
# Complete setup (interactive prompts)
.\setup-complete-infrastructure.ps1 `
    -ResourceGroup "tc-cloudgames-solution-dev-rg" `
    -ClusterName "tc-cloudgames-dev-cr8n-aks" `
    -KeyVaultName "tccloudgamesdevcr8nkv"

# With Force reinstall and skip deploy
.\setup-complete-infrastructure.ps1 `
    -ResourceGroup "tc-cloudgames-solution-dev-rg" `
    -ClusterName "tc-cloudgames-dev-cr8n-aks" `
    -KeyVaultName "tccloudgamesdevcr8nkv" `
    -Force `
    -SkipDeploy
```

## 🎮 Interactive Menu: aks-manager.ps1

**Purpose**: User-friendly interface for all operations

**Features**:
- ✅ Visual status indicators (green = installed, gray = not installed)
- ✅ Parallel status checks with animated spinner
- ✅ Individual component installation options
- ✅ Complete setup orchestration
- ✅ Command-line interface support
- ✅ ACR build info with timestamps
- ✅ LoadBalancer IP display

**Menu Structure**:
```
[1] Connect to AKS cluster
[2] Show cluster status

COMPONENT INSTALLATION:
[3] Install NGINX Ingress (installed) ✓
    • LoadBalancer IP: 20.x.x.x
[4] Install External Secrets Operator (installed) ✓
[5] Install Grafana Agent (not installed)

ARGOCD & DEPLOYMENT:
[6] Install ArgoCD (installed) ✓
[7] Get ArgoCD URL & credentials

CONFIGURATION:
[8] Setup ESO with Workload Identity
[9] Bootstrap ArgoCD PROD app (installed) ✓

BUILD & DEPLOY:
[10] Build & Push images to ACR
     • users-api:   tag v1.0.0 at 2024-12-16T10:30:00Z
     • games-api:   tag v1.0.1 at 2024-12-16T11:00:00Z
     • payms-api:   tag v1.0.0 at 2024-12-16T09:45:00Z

UTILITIES:
[11] View logs
[12] Post-Terraform Complete Setup
     (All-in-one: connect, nginx, ESO, WI, grafana, deploy)

[0] Exit
```

**Usage**:
```powershell
# Interactive menu
.\aks-manager.ps1

# Command-line (individual components)
.\aks-manager.ps1 install-nginx
.\aks-manager.ps1 install-eso
.\aks-manager.ps1 install-grafana

# Command-line (complete setup)
.\aks-manager.ps1 post-terraform-setup

# Help
.\aks-manager.ps1 --help
```

## 🔄 Idempotency Strategy

All installation scripts follow this pattern:

1. **Check existing installation** (via `helm list`)
2. **If exists and no `-Force`**: Upgrade in-place (no downtime)
3. **If exists and `-Force`**: Uninstall → Delete namespace → Reinstall
4. **If not exists**: Fresh installation

This ensures:
- ✅ Safe to run multiple times
- ✅ No accidental deletions (unless `-Force`)
- ✅ Minimal downtime (upgrade in-place default)
- ✅ Clean reinstall when needed

## 📊 Status Detection

The menu performs parallel status checks for:
- ✅ NGINX Ingress (pods + LoadBalancer IP)
- ✅ External Secrets Operator (pods)
- ✅ Grafana Agent (pods)
- ✅ ArgoCD (pods)
- ✅ ArgoCD Applications (cloudgames-prod)
- ✅ ACR image tags (last build info)

**Performance**: All checks run in parallel jobs with animated spinner (fast UX)

## 🔐 Security: Workload Identity

**Architecture**:
```
Azure Key Vault ─────────┐
                         │
Azure Service Bus ───────┤
                         │
                         ├──► Azure Managed Identity
                         │    (RBAC assignments)
                         │
                         ├──► Federated Credential
                         │    (OIDC trust with AKS)
                         │
                         └──► ServiceAccount
                              (annotated with client-id + tenant-id)
                              │
                              └──► ClusterSecretStore
                                   (WorkloadIdentity authType)
                                   │
                                   └──► ExternalSecret resources
```

**Key Points**:
- ✅ No secrets/connection strings in cluster
- ✅ OIDC-based authentication
- ✅ RBAC for Key Vault and Service Bus
- ✅ Tenant-id annotation is **critical** (prevents InvalidProviderConfig)

## 🚀 Common Workflows

### First-Time Setup (After Terraform Apply)
```powershell
# Option 1: Interactive menu
.\aks-manager.ps1
# Choose option [12] Post-Terraform Complete Setup

# Option 2: Command line
.\aks-manager.ps1 post-terraform-setup
```

### Install Individual Component
```powershell
# Interactive menu
.\aks-manager.ps1
# Choose option [3], [4], or [5]

# Command line
.\aks-manager.ps1 install-nginx
.\aks-manager.ps1 install-eso
.\aks-manager.ps1 install-grafana
```

### Reinstall Component (Clean)
```powershell
# Interactive menu prompts for Force option
.\aks-manager.ps1
# Choose component → Answer "Y" to Force reinstall

# Direct script call
.\install-nginx-ingress.ps1 -ResourceGroup "rg" -ClusterName "aks" -Force
```

### Troubleshooting
```powershell
# Check status
.\aks-manager.ps1 status

# View logs
.\aks-manager.ps1 logs nginx
.\aks-manager.ps1 logs eso
.\aks-manager.ps1 logs grafana-agent

# Reinstall problematic component
.\aks-manager.ps1 install-nginx  # Choose Force=Y if needed
```

## 📝 Maintenance Guidelines

### Adding New Component
1. Create standalone script `install-<component>.ps1`
2. Include `-Force` parameter for idempotency
3. Add check in `Get-InstallStatuses` (aks-manager.ps1)
4. Add menu option with status indicator
5. Add command handler in `Invoke-Command`
6. Update help text and examples

### Modifying Complete Setup
1. Edit `setup-complete-infrastructure.ps1`
2. Call standalone scripts (don't inline code)
3. Pass parameters via `@installArgs` splatting
4. Test with `-Force`, `-SkipDeploy`, `-SkipGrafana` combinations

### Best Practices
- ✅ Always use standalone scripts (avoid duplication)
- ✅ Keep scripts idempotent
- ✅ Provide clear user feedback
- ✅ Use color coding (Green=success, Yellow=warning, Red=error)
- ✅ Include validation and error handling
- ✅ Document parameters and examples

## 🎓 Key Lessons Learned

1. **Code Duplication**: Initially inlined ESO WI setup → created maintenance issues
   - **Solution**: Keep standalone scripts, call them from orchestrator

2. **Missing Annotation**: `InvalidProviderConfig` error due to missing `tenant-id`
   - **Solution**: Always include both `client-id` and `tenant-id` annotations

3. **Terraform APIM Routes**: 400 errors from path mismatches
   - **Solution**: Align Ingress paths (`/games`, `/user`, `/payments`) with APIM backends

4. **User Experience**: Hard to know what's installed
   - **Solution**: Parallel status checks with visual indicators in menu

5. **Idempotency**: Needed safe reruns without downtime
   - **Solution**: Default to upgrade in-place, `-Force` for clean reinstall

## 📚 Related Documentation

- `POST-TERRAFORM-SETUP.md` - Step-by-step manual setup guide
- `INSTALLATION_GUIDE.md` - Complete installation documentation
- `setup-eso-workload-identity.ps1` - Workload Identity configuration details
- Terraform modules: `../../terraform/foundation/modules/apim/`

## 🔄 Version History

- **v1.0** (2024-12-16): Modular architecture with standalone scripts
  - Extracted NGINX, ESO, Grafana into standalone scripts
  - Refactored complete setup to call standalone scripts
  - Added visual status indicators to interactive menu
  - Implemented parallel status checks with spinner
  - Added LoadBalancer IP display
  - Documented architecture and workflows

---

**Maintained by**: TC CloudGames Infrastructure Team  
**Last Updated**: December 16, 2024
