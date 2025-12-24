# 🚀 TC CloudGames - AKS Production Guide

> **Complete guide for Azure Kubernetes Service (AKS) infrastructure management**

## 📖 Table of Contents

- [Quick Start](#-quick-start)
- [Architecture Overview](#-architecture-overview)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Component Management](#-component-management)
- [Verification](#-verification)
- [Troubleshooting](#-troubleshooting)
- [Common Workflows](#-common-workflows)

---

## ⚡ Quick Start

### Option 1: Automated Complete Setup (Recommended)

```powershell
cd infrastructure/kubernetes/scripts/prod

# Interactive menu
.\aks-manager.ps1

# Choose option [12] Post-Terraform Complete Setup
```

**What it does:**
1. ✅ Connects to AKS cluster
2. ✅ Installs NGINX Ingress Controller
3. ✅ Obtains LoadBalancer IP
4. ✅ Updates Terraform with NGINX IP
5. ✅ Re-runs Terraform to configure APIM backends
6. ✅ Installs External Secrets Operator
7. ✅ Configures Workload Identity (passwordless auth)
8. ✅ Deploys applications via Kustomize
```powershell
# Complete setup
.\aks-manager.ps1 post-terraform-setup

# Individual components
.\aks-manager.ps1 install-nginx
.\aks-manager.ps1 install-eso
.\aks-manager.ps1 install-argocd
.\aks-manager.ps1 configure-image-updater
```

---

## 📐 Architecture Overview

This project uses a **modular, DRY architecture** with standalone scripts orchestrated by a central manager.

```
aks-manager.ps1 (Main Entry Point)
    │
    ├─► install-nginx-ingress.ps1
    ├─► install-external-secrets.ps1
    ├─► install-argocd-aks.ps1
    ├─► setup-eso-workload-identity.ps1
    │
    └─► setup-complete-infrastructure.ps1 (Orchestrator)
```

**📚 For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md)**

**Design Principles:**
- ✅ **DRY**: No code duplication
- ✅ **Modular**: Each component independently installable
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **User-Friendly**: Visual status indicators

---

## 📋 Prerequisites

**Required Tools:**
- ✅ Azure CLI (`az`) - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)
- ✅ kubectl - [Install](https://kubernetes.io/docs/tasks/tools/)
- ✅ Helm v3 - [Install](https://helm.sh/docs/intro/install/)
- ✅ PowerShell 7+ (Windows/Linux/macOS)

**Azure Resources (Created by Terraform):**
- Azure Kubernetes Service (AKS) cluster
- Azure Key Vault with secrets
- Azure Container Registry (ACR)
- Azure Service Bus (messaging)
- Azure API Management (APIM)

**Verify Prerequisites:**

```powershell
# Check tools
az --version
kubectl version --client
helm version

# Login to Azure
az login

# Verify Terraform completed
az aks show --resource-group tc-cloudgames-solution-dev-rg --name tc-cloudgames-dev-cr8n-aks
```

---

## 🔧 Installation

### Step 1: Connect to AKS

```powershell
# Via aks-manager
.\aks-manager.ps1 connect

# Or manually
az aks get-credentials `
  --resource-group tc-cloudgames-solution-dev-rg `
  --name tc-cloudgames-dev-cr8n-aks `
  --overwrite-existing

# Verify
kubectl cluster-info
kubectl get nodes
```

### Step 2: Install Components

#### Interactive Menu

```powershell
.\aks-manager.ps1
```

**Menu Structure:**
```
[1] 🔌 Connect to AKS cluster
[2] 📊 Show cluster status

COMPONENT INSTALLATION:
[3] 📦 Install NGINX Ingress (installed) ✓
    • LoadBalancer IP: 20.x.x.x
[4] 🔐 Install External Secrets Operator (installed) ✓
[5] 📦 Install ArgoCD (installed) ✓
[6] 🔄 Configure Image Updater (installed) ✓

ARGOCD & DEPLOYMENT:
[7] 🔗 Get ArgoCD URL & credentials

CONFIGURATION:
[8] 🔐 Setup ESO with Workload Identity
[9] 📋 Bootstrap ArgoCD PROD app

BUILD & DEPLOY:
[10] 🐳 Build & Push images to ACR
[11] 📝 View logs
[12] 🔧 Post-Terraform Complete Setup

[0] ❌ Exit
```

#### Command Line

```powershell
# Individual components
.\aks-manager.ps1 install-nginx
.\aks-manager.ps1 install-eso
.\aks-manager.ps1 install-argocd
.\aks-manager.ps1 configure-image-updater

# Configuration
.\aks-manager.ps1 setup-eso-wi

# Deployment
.\aks-manager.ps1 bootstrap
```

---

## 📦 Component Management

### NGINX Ingress Controller

**Purpose:** Single LoadBalancer for all services (cost savings: $80/month)

```powershell
# Install/Upgrade
.\aks-manager.ps1 install-nginx

# Force reinstall
.\install-nginx-ingress.ps1 -ResourceGroup "rg-name" -ClusterName "aks-name" -Force

# Get LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

**Features:**
- ✅ Production-ready resource limits
- ✅ Health probe configuration
- ✅ Automatic LoadBalancer IP assignment
- ✅ Idempotent (upgrade in-place by default)

### External Secrets Operator

**Purpose:** Sync secrets from Azure Key Vault to Kubernetes

```powershell
# Install ESO
.\aks-manager.ps1 install-eso

# Configure Workload Identity (recommended)
.\aks-manager.ps1 setup-eso-wi

# Verify
kubectl get externalsecrets -n cloudgames
kubectl get clustersecretstore
```

**Features:**
- ✅ Automatic secret synchronization
- ✅ Azure Workload Identity (no passwords)
- ✅ Dynamic updates (no pod restart)
- ✅ RBAC for Key Vault and Service Bus

**Secret Flow:**
```
Azure Key Vault
    ↓ (Workload Identity)
External Secrets Operator
    ↓ (creates)
Kubernetes Secrets
    ↓ (consumed by)
Application Pods
```

### ArgoCD (GitOps)

**Purpose:** Declarative deployments via Git

```powershell
# Install
.\aks-manager.ps1 install-argocd

# Get URL & credentials
.\aks-manager.ps1 get-argocd-url

# Bootstrap applications
.\aks-manager.ps1 bootstrap
```

**Default Credentials:**
- Username: `admin`
- Password: `Argo@AKS123!`

---

## ✅ Verification

### Check All Components

```powershell
# Complete overview
.\aks-manager.ps1 status

# Individual checks
kubectl get pods -n ingress-nginx
kubectl get pods -n external-secrets
kubectl get pods -n argocd
kubectl get pods -n cloudgames
```

### Check Secrets Synchronization

```powershell
# ExternalSecrets status
kubectl get externalsecrets -n cloudgames

# Created Kubernetes secrets
kubectl get secrets -n cloudgames

# Verify ESO is syncing
kubectl describe externalsecret games-api-secrets -n cloudgames
```

**Expected Output:**
```
NAME                   STORE              REFRESH INTERVAL   STATUS      READY
games-api-secrets      azure-keyvault     1h                 SecretSynced True
user-api-secrets       azure-keyvault     1h                 SecretSynced True
payments-api-secrets   azure-keyvault     1h                 SecretSynced True
```

### Check Ingress

```powershell
# Get NGINX LoadBalancer IP
$NGINX_IP = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "NGINX IP: $NGINX_IP"

# Test endpoints
curl "http://$NGINX_IP/health" -H "Host: games-api.cloudgames.local"
curl "http://$NGINX_IP/health" -H "Host: user-api.cloudgames.local"
curl "http://$NGINX_IP/health" -H "Host: payments-api.cloudgames.local"
```

**Expected Response:**
```json
{
  "status": "Healthy",
  "totalDuration": "00:00:00.0123456"
}
```

---

## 🐛 Troubleshooting

### NGINX Ingress Issues

```powershell
# Check logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# Check service
kubectl describe svc -n ingress-nginx ingress-nginx-controller

# Check events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'

# Reinstall (if needed)
.\aks-manager.ps1 install-nginx
# Choose "Y" for Force reinstall
```

### External Secrets Not Syncing

```powershell
# Check ClusterSecretStore
kubectl get clustersecretstore -o yaml

# Check ESO logs
kubectl logs -n external-secrets deployment/external-secrets -f

# Check ExternalSecret details
kubectl describe externalsecret games-api-secrets -n cloudgames

# Force resync
kubectl delete secret games-api-secrets -n cloudgames
kubectl get externalsecrets -n cloudgames --watch
```

**Common Issues:**
- ❌ Workload Identity not configured → Run `.\aks-manager.ps1 setup-eso-wi`
- ❌ Key Vault permissions missing → Check RBAC assignments
- ❌ Missing tenant-id annotation → Reinstall ESO WI setup
- ❌ Secret name mismatch → Verify Key Vault secret names

### Pods in CrashLoopBackOff

```powershell
# Check current logs
kubectl logs -n cloudgames <pod-name>

# Check previous logs (after crash)
kubectl logs -n cloudgames <pod-name> --previous

# Check events
kubectl describe pod -n cloudgames <pod-name>

# Common causes:
# - Missing secrets → Check ExternalSecrets
# - Database connection failure → Check connection string
# - OOMKilled → Increase memory limits
```

### View Component Logs

```powershell
# Via aks-manager
.\aks-manager.ps1 logs nginx
.\aks-manager.ps1 logs eso
.\aks-manager.ps1 logs argocd

# Or manually
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
```

---

## 🚀 Common Workflows

### First-Time Setup (After Terraform Apply)

```powershell
# Automated (recommended)
.\aks-manager.ps1
# Choose [12] Post-Terraform Complete Setup

# Or manual steps
.\aks-manager.ps1 connect
.\aks-manager.ps1 install-nginx
.\aks-manager.ps1 install-eso
.\aks-manager.ps1 setup-eso-wi
.\aks-manager.ps1 bootstrap
```

### Update Application Images

```powershell
# Build and push to ACR
.\aks-manager.ps1 build-push

# If using ArgoCD
# - Images are automatically detected and deployed
# - Check ArgoCD UI for sync status

# If using Kustomize directly
kubectl apply -k infrastructure/kubernetes/overlays/prod
kubectl rollout restart deployment -n cloudgames
```

### Reinstall Component

```powershell
# Via menu (prompts for Force option)
.\aks-manager.ps1
# Choose component → Answer "Y" to Force reinstall

# Direct script call
.\install-nginx-ingress.ps1 -ResourceGroup "rg" -ClusterName "aks" -Force
.\install-external-secrets.ps1 -ResourceGroup "rg" -ClusterName "aks" -Force
```

### Update NGINX IP in Terraform

```powershell
# Get current NGINX IP
$NGINX_IP = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Update Terraform
cd infrastructure/terraform/foundation
@"
nginx_ingress_ip = "$NGINX_IP"
"@ | Add-Content terraform.tfvars

# Apply
terraform plan -out=tfplan
terraform apply tfplan
```

### Bootstrap ArgoCD Applications

```powershell
# Production
.\aks-manager.ps1 bootstrap

# Or manually
kubectl apply -f ../../manifests/application-cloudgames-project-prod.yaml
kubectl apply -f ../../manifests/application-cloudgames-prod.yaml

# Verify
kubectl get applications -n argocd
```

---

## 📚 Additional Documentation

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Detailed technical architecture, design principles, and script relationships |
| [../../README.md](../../README.md) | Kubernetes overview (dev + prod) |

---

## 📊 Component Status Reference

| Component | Namespace | Purpose | Required |
|-----------|-----------|---------|----------|
| **NGINX Ingress** | `ingress-nginx` | LoadBalancer + routing | ✅ Yes |
| **External Secrets** | `external-secrets` | Key Vault sync | ✅ Yes |
| **Workload Identity** | System-wide | Passwordless auth | ✅ Yes |
| **ArgoCD** | `argocd` | GitOps deployment | ⚠️ Optional |

---

## 💡 Tips

### PowerShell Alias

```powershell
# Add to PowerShell profile
notepad $PROFILE

# Add this line:
Set-Alias aks "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\prod\aks-manager.ps1"

# Reload
. $PROFILE

# Usage
aks                    # Interactive menu
aks status            # Cluster status
aks install-nginx     # Install NGINX
```

### Cost Optimization

**NGINX Ingress = $80/month savings**
- ❌ Without NGINX: 3 LoadBalancers × $40 = $120/month
- ✅ With NGINX: 1 LoadBalancer = $40/month
- 💰 **Savings: 67%**

### Health Check Endpoints

All APIs expose health endpoints:
- `GET /health` - Overall health
- `GET /health/ready` - Readiness probe
- `GET /health/live` - Liveness probe

---

## 🔐 Security: Workload Identity

**No secrets/passwords in cluster!**

```
Azure Key Vault ──┐
                  │
Azure Service Bus ┤
                  │
                  ├─► Azure Managed Identity (RBAC)
                  │
                  ├─► Federated Credential (OIDC)
                  │
                  └─► ServiceAccount (annotations)
                      │
                      └─► ClusterSecretStore
                          │
                          └─► ExternalSecret resources
```

**Critical Annotations:**
- `azure.workload.identity/client-id`: `<client-id>`
- `azure.workload.identity/tenant-id`: `<tenant-id>` ⚠️ **Required!**

---

## 📝 Script Reference

| Script | Purpose | Idempotent |
|--------|---------|------------|
| `aks-manager.ps1` | Main entry point (menu + CLI) | N/A |
| `setup-complete-infrastructure.ps1` | Complete post-Terraform setup | ✅ Yes |
| `install-nginx-ingress.ps1` | NGINX Ingress installation | ✅ Yes |
| `install-external-secrets.ps1` | ESO installation | ✅ Yes |
| `install-argocd-aks.ps1` | ArgoCD installation | ✅ Yes |
| `setup-eso-workload-identity.ps1` | ESO + Workload Identity | ✅ Yes |
| `build-push-acr.ps1` | Build/push Docker images | ✅ Yes |

---

**Maintained by**: TC CloudGames Infrastructure Team  
**Last Updated**: December 16, 2024  
**Version**: 1.0.0
