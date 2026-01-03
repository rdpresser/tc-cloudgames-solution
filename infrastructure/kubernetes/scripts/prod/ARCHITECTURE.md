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
├── aks-manager.ps1                              # Main orchestrator with interactive menu
│
├── install-nginx-ingress.ps1                   # NGINX Ingress Controller (standalone)
├── install-external-secrets.ps1                # External Secrets Operator (standalone)
├── install-argocd-aks.ps1                      # ArgoCD (standalone)
│
├── setup-eso-workload-identity.ps1            # ESO + Workload Identity configuration
├── configure-image-updater.ps1                # ArgoCD Image Updater setup
├── build-push-acr.ps1                         # Build and push Docker images
│
├── check-helm-chart-versions.ps1              # Check for Helm chart updates
├── update-helm-chart-version.ps1              # Update Helm chart versions
├── check-argocd-updates.ps1                   # Check for ArgoCD updates
│
├── fix-webhooks.ps1                           # Validate webhook health (diagnosis)
├── fix-argocd-sync.ps1                        # Sync applications in order (orchestration)
├── fix-ingress-webhook-cabundle.ps1           # Fix NGINX webhook certificates (specific)
├── fix-federated-credentials-after-aks-recreation.ps1  # Fix OIDC after AKS recreation
├── cluster-cleanup-audit.ps1                  # Audit unused resources
├── force-delete-namespace.ps1                 # Force delete stuck namespaces
│
├── wait-for-components.ps1                    # Wait for component readiness
├── ARCHITECTURE.md                            # This file (complete architecture)
├── README.md                                  # Complete getting started guide
└── QUICK_START.md                             # 3-step quick start
```

## 🔄 Script Relationships

```
┌──────────────────────────────────────────────────────────────┐
│                    aks-manager.ps1                            │
│             (Main Entry Point + Menu)                        │
│                                                              │
│  • Interactive menu with status indicators                  │
│  • Individual component installation                        │
│  • Complete setup orchestration (post-terraform-setup)     │
│  • Command-line interface                                   │
└──────────────────┬─────────────────────────────────────────┘
                   │
        ┌──────────┼──────────────┬──────────────┬────────────┐
        │          │              │              │            │
        ▼          ▼              ▼              ▼            ▼
   INSTALLATION   CONFIGURATION  FIX & SYNC     UTILITIES    BUILD
        │          │              │              │            │
        ├─► install-nginx-ingress.ps1           │            │
        │   install-external-secrets.ps1        │            │
        │   install-argocd-aks.ps1              │            │
        │                                        │            │
        ├─► setup-eso-workload-identity.ps1     │            │
        │   configure-image-updater.ps1         │            │
        │                                        │            │
        ├─► fix-webhooks.ps1 ──┐                │            │
        │       │               │                │            │
        │       └─► fix-ingress-webhook-cabundle.ps1         │
        │   fix-argocd-sync.ps1                 │            │
        │   fix-federated-credentials-...ps1    │            │
        │                                        │            │
        ├─► check-helm-chart-versions.ps1       │            │
        │   check-argocd-updates.ps1            │            │
        │   update-helm-chart-version.ps1       │            │
        │   cluster-cleanup-audit.ps1           │            │
        │   force-delete-namespace.ps1          │            │
        │                                        │            │
        └────────────────────────────────────────────────────► build-push-acr.ps1
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

### 3. setup-eso-workload-identity.ps1
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

## � Interactive Menu: aks-manager.ps1

**Purpose**: User-friendly interface for all operations

**Features**:
- ✅ Visual status indicators (green = installed, gray = not installed)
- ✅ Parallel status checks with animated spinner
- ✅ Individual component installation options
- ✅ Complete setup orchestration (`post-terraform-setup`)
- ✅ Command-line interface support
- ✅ ACR build info with timestamps
- ✅ LoadBalancer IP display

**Usage**:
```powershell
# Interactive menu
.\aks-manager.ps1

# Command-line (individual components)
.\aks-manager.ps1 install-nginx
.\aks-manager.ps1 install-eso

# Command-line (complete setup - RECOMMENDED)
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
- ✅ ArgoCD (pods)
- ✅ ArgoCD Applications (cloudgames-prod)
- ✅ ArgoCD Image Updater (pods)
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
4. Test with `-Force` and `-SkipDeploy` combinations

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

- **v1.1** (2026-01-03): Fix Scripts Architecture & Webhook Validation
  - Added webhook validation and sync orchestration scripts
  - Documented fix scripts architecture (webhooks, sync, federated credentials)
  - Removed code duplication between fix scripts
  - Established clear responsibilities: diagnosis vs. correction vs. sync
  
- **v1.0** (2024-12-16): Modular architecture with standalone scripts
  - Extracted NGINX and ESO into standalone scripts
  - Refactored complete setup to call standalone scripts
  - Added visual status indicators to interactive menu
  - Implemented parallel status checks with spinner
  - Added LoadBalancer IP display
  - Documented architecture and workflows

---

## 🔧 Fix Scripts Architecture (Webhook & Sync Issues)

### Problem Context
After recreating AKS clusters or during initial deployment, webhook validation errors can prevent ArgoCD from syncing resources:
- NGINX Ingress webhook certificate issues (`x509: certificate signed by unknown authority`)
- External Secrets Operator webhook endpoints not ready
- Federated identity credentials pointing to old OIDC issuer URLs

### Fix Scripts Design Principles

**Complementary with Clear Responsibilities:**
```
post-terraform-setup (Step 7)
├─► fix-webhooks.ps1 (diagnosis)
│   └─► fix-ingress-webhook-cabundle.ps1 (auto-called if needed)
└─► fix-argocd-sync.ps1 (ordered sync with retry)
```

### 1. fix-webhooks.ps1 - DIAGNOSIS 🔍

**Purpose:** Validate health of all webhooks before sync

**Responsibilities:**
- ✅ Checks NGINX Ingress webhook certificate (caBundle)
- ✅ If caBundle invalid → **CALLS** `fix-ingress-webhook-cabundle.ps1`
- ✅ Verifies External Secrets Operator webhook endpoints
- ✅ Verifies Azure Workload Identity webhook
- ✅ Returns exit code 0 if all OK, 1 if problems detected

**Does NOT:**
- ❌ Does not sync applications
- ❌ Does not alter state, only diagnoses

**When to use:**
- In post-terraform-setup (Step 7)
- When encountering webhook validation errors
- Before manual sync

**Usage:**
```powershell
.\fix-webhooks.ps1
# Exit code 0 = all webhooks ready
# Exit code 1 = issues detected
```

---

### 2. fix-ingress-webhook-cabundle.ps1 - SPECIFIC FIX 🔨

**Purpose:** Fix ONLY the NGINX webhook caBundle

**Responsibilities:**
- ✅ Extracts caBundle from secret `ingress-nginx-admission`
- ✅ Updates ValidatingWebhookConfiguration
- ✅ Verifies fix was applied

**Does NOT:**
- ❌ **DOES NOT sync** (removed redundancy)
- ❌ Does not validate other webhooks
- ❌ Not called directly in post-terraform

**When to use:**
- **Automatically** called by `fix-webhooks.ps1` if needed
- Manually via menu [21] for specific correction

**Usage:**
```powershell
# Usually auto-called, but can run manually
.\fix-ingress-webhook-cabundle.ps1
```

---

### 3. fix-argocd-sync.ps1 - SYNC ORCHESTRATION 🔄

**Purpose:** Synchronize applications in correct order with retry logic

**Responsibilities:**
- ✅ Verifies prerequisites (kubectl, ArgoCD)
- ✅ Ordered sync: Workload Identity → NGINX → ESO → cloudgames-prod
- ✅ Automatic retry (up to 2-3 times per app)
- ✅ Detects specific issues (ClusterSecretStore, pods)
- ✅ Final status report of all applications

**Does NOT:**
- ❌ **DOES NOT validate webhooks** (removed redundancy)
- ❌ Does not fix certificate problems

**When to use:**
- In post-terraform-setup (Step 7, after fix-webhooks)
- When applications are OutOfSync
- After manual manifest changes

**Usage:**
```powershell
.\fix-argocd-sync.ps1
```

---

### 4. fix-federated-credentials-after-aks-recreation.ps1 - OIDC FIX 🔐

**Purpose:** Update federated credentials after recreating AKS

**Responsibilities:**
- ✅ Gets new OIDC Issuer URL from AKS
- ✅ Deletes federated credentials with old issuer
- ✅ Recreates with correct issuer
- ✅ Validates if already correct (idempotent)

**When to use:**
- **ALWAYS** after recreating an AKS cluster
- When ESO returns error `AADSTS700211: No matching federated identity record`

**Usage:**
```powershell
.\fix-federated-credentials-after-aks-recreation.ps1
```

---

### Optimized Workflow (No Redundancy)

**Before (with redundancies):**
```
fix-webhooks → validates webhooks
    └─> calls fix-ingress-webhook-cabundle
        └─> syncs cloudgames-prod ❌ REDUNDANT

fix-argocd-sync → validates webhooks AGAIN ❌ REDUNDANT
    └─> syncs cloudgames-prod AGAIN ❌ DUPLICATE
```

**After (optimized):**
```
fix-webhooks → validates webhooks
    └─> calls fix-ingress-webhook-cabundle (if needed)
        └─> ONLY fixes caBundle ✅

fix-argocd-sync → ordered sync with retry ✅
    └─> cloudgames-prod synced ONCE ✅
```

**Benefits:**
- ✅ No duplicate webhook validation
- ✅ No duplicate sync
- ✅ Clear responsibilities (diagnosis vs. correction vs. sync)
- ✅ Guaranteed idempotency
- ✅ Reduced execution time (~40% faster)

---

### When to Use Each Fix Script

| Script | Menu Option | Scenario |
|--------|-------------|----------|
| `fix-webhooks` | [22] | Webhook validation errors |
| `fix-argocd-sync` | [20] | Applications OutOfSync |
| `fix-ingress-webhook-cabundle` | [21] | Specific caBundle problem |
| `fix-federated-credentials...` | None | **AFTER recreating AKS** |
| `reset-argocd-password` | [7a] | ArgoCD login failed |

---

### post-terraform-setup Integration

The complete setup includes webhook validation and sync as final steps:

```powershell
# Step 7: Webhook Validation + Sync
Write-Host "═══ Step 7/7: Validation + Sync ═══"

# 7.1 Validate webhooks (diagnosis)
& "$PSScriptRoot\fix-webhooks.ps1"

# 7.2 Ordered sync with retry
& "$PSScriptRoot\fix-argocd-sync.ps1"
```

**Execution time:** ~5-8 minutes (vs. ~10-15 minutes with redundancies)

---

**Maintained by**: TC CloudGames Infrastructure Team  
**Last Updated**: January 3, 2026
