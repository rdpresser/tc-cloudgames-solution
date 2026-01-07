# 🚀 TC CloudGames - AKS Production Setup

> **Complete guide for setting up and managing Azure Kubernetes Service (AKS) production cluster**

## 📖 Table of Contents

- [⚡ Quick Start - Happy Path](#-quick-start---happy-path)
- [📋 Prerequisites](#-prerequisites)
- [🚀 Installation Steps](#-installation-steps)
- [✅ Verification](#-verification)
- [🐛 Troubleshooting](#-troubleshooting)
- [🚀 Common Workflows](#-common-workflows)
- [⚠️ Advanced: Cluster Reset](#-advanced-cluster-reset)
- [📚 Reference](#-reference)

---

# ⚡ Quick Start - Happy Path

### 🎯 Complete Production Setup (Recommended)

This is the recommended flow for a **new AKS cluster after Terraform completes**:

#### Step 1: Terraform Infrastructure
```powershell
cd infrastructure/terraform/foundation

# Initialize Terraform (first time only)
terraform init

# Plan infrastructure
terraform plan -out=tfplan

# Create all infrastructure (5-15 minutes)
terraform apply tfplan

# ✅ Creates: AKS, ACR, Key Vault, Service Bus, Databases, Networking, etc.
```

#### Step 2: Post-Terraform Setup (One Command!)
```powershell
cd infrastructure/kubernetes/scripts/prod

# Run complete setup
.\aks-manager.ps1 post-terraform-setup
```

**Automatically configures:**
- ✅ Updates ServiceAccount client IDs from Terraform outputs (Workload Identity)
- ✅ Connects to AKS cluster
- ✅ Installs ArgoCD (GitOps)
- ✅ Bootstraps all applications (NGINX, ESO, Workload Identity, Apps)
- ✅ Configures secret synchronization from Azure Key Vault
- ✅ Enables automatic container image updates from ACR

**Done! Your production cluster is ready.**

#### Step 3: Access & Verify
```powershell
# Get ArgoCD dashboard URL
.\aks-manager.ps1 get-argocd-url

# Check overall status
.\aks-manager.ps1 status

# View deployed applications
kubectl get applications -n argocd
```

---

## 📋 Prerequisites

### Required Tools

- **Azure CLI** - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)
  ```powershell
  az --version    # Should be recent
  az login        # Login to your Azure account
  ```

- **kubectl** - [Install](https://kubernetes.io/docs/tasks/tools/)
  ```powershell
  kubectl version --client
  ```

- **Helm v3** - [Install](https://helm.sh/docs/intro/install/)
  ```powershell
  helm version
  ```

- **Terraform 1.14.x** - [Install](https://developer.hashicorp.com/terraform/install#windows)
  ```powershell
  terraform version
  ```

- **PowerShell 7+** (Windows/Linux/macOS)

### Azure Requirements

- Subscription with **Owner or Contributor** role
- Valid Azure login: `az login`
- Region resources available (check quota)

---

## 🚀 Installation Steps

### Step 1: Create Azure Infrastructure with Terraform

```powershell
# Navigate to Terraform directory
cd infrastructure/terraform/foundation

# Initialize (first time only)
terraform init

# View what will be created
terraform plan -out=tfplan

# Create infrastructure
terraform apply tfplan

# Wait for completion (5-15 minutes)
```

**Infrastructure created:**
- **AKS**: Kubernetes cluster (production-grade)
- **ACR**: Container registry for images
- **Key Vault**: Secrets management
- **PostgreSQL**: Databases for each service
- **Service Bus**: Messaging (event-driven)
- **Virtual Network**: Networking & subnets
- **Storage**: Backup & logging
- **Monitoring**: Observability resources

### Step 2: Complete AKS Post-Terraform Setup

```powershell
# Navigate to scripts
cd infrastructure/kubernetes/scripts/prod

# Run ONE command that does everything
.\aks-manager.ps1 post-terraform-setup

# OR use interactive menu
.\aks-manager.ps1
# Select menu option [12] "Post-Terraform Complete Setup"
```

**What this does:**

0. **Updates ServiceAccount client IDs** - Fetches managed identity client IDs from Terraform and updates Kubernetes ServiceAccount YAML files for Workload Identity integration
1. **Connects to cluster** - Gets credentials from Azure
2. **Installs ArgoCD** - GitOps platform for deployments
3. **Bootstraps applications** - Deploys all apps via ArgoCD
4. **Sets up ESO** - External Secrets Operator syncs secrets from Key Vault
5. **Configures Workload Identity** - Passwordless authentication (recommended)
6. **Enables Image Updater** - Automatically detects & deploys new images from ACR
7. **Verifies health** - Ensures all components are running

**Expected output:**
```
✅ Connected to AKS cluster: tc-cloudgames-dev-cr8n-aks
✅ ArgoCD installed successfully (namespace: argocd)
✅ Bootstrap application deployed
✅ ESO ClusterSecretStore configured
✅ Workload Identity setup completed
✅ ArgoCD Image Updater enabled
✅ All components verified and healthy
```

### Step 3: Access Your Deployment

```powershell
# Get ArgoCD URL and credentials
.\aks-manager.ps1 get-argocd-url

# Example output:
# URL:      http://20.XX.XX.XX
# Username: admin
# Password: [initial password]
```

---

## ✅ Verification

### Check Cluster Health

```powershell
# Complete status overview
.\aks-manager.ps1 status

# This shows:
# ✅ Azure account & subscription
# ✅ AKS cluster state (Running/Stopped)
# ✅ Installed components (ArgoCD, NGINX, ESO)
# ✅ LoadBalancer IPs
# ✅ Node count and health
```

### Check Components Running

```powershell
# All ArgoCD applications
kubectl get applications -n argocd

# All pods across system
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
kubectl get pods -n external-secrets
kubectl get pods -n cloudgames
```

### Verify Secrets Synchronization

```powershell
# Check ExternalSecrets are synced
kubectl get externalsecrets -n cloudgames

# Expected output:
# NAME                   STORE              STATUS         READY
# games-api-secrets      azure-keyvault     SecretSynced   True
# user-api-secrets       azure-keyvault     SecretSynced   True
# payments-api-secrets   azure-keyvault     SecretSynced   True

# Verify secrets created in Kubernetes
kubectl get secrets -n cloudgames
```

### Test Service Endpoints

```powershell
# Get NGINX LoadBalancer IP
$NGINX_IP = kubectl get svc ingress-nginx-controller -n ingress-nginx `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "NGINX LoadBalancer IP: $NGINX_IP"

# Test API health endpoints
curl "http://$NGINX_IP/health" -H "Host: user-api.cloudgames.local"
curl "http://$NGINX_IP/health" -H "Host: games-api.cloudgames.local"
curl "http://$NGINX_IP/health" -H "Host: payments-api.cloudgames.local"

# Should respond with:
# {"status":"Healthy","totalDuration":"00:00:00.0123456"}
```

---

## 🐛 Troubleshooting

### Issue: NGINX Ingress Not Getting LoadBalancer IP

**Symptoms:** `kubectl get svc -n ingress-nginx` shows `<pending>` for EXTERNAL-IP

**Solution:**
```powershell
# Check service status
kubectl describe svc -n ingress-nginx ingress-nginx-controller

# Check logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# Reinstall NGINX
.\aks-manager.ps1 install-nginx

# Wait a few minutes for Azure to assign IP
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch
```

### Issue: External Secrets Not Syncing

**Symptoms:** ExternalSecrets show `SecretSyncFailed` or `PendingSecretRefresh`

**Solution:**
```powershell
# Check ESO logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f

# Verify ClusterSecretStore configuration
kubectl get clustersecretstore -o yaml

# Check specific ExternalSecret details
kubectl describe externalsecret games-api-secrets -n cloudgames

# Common fixes:
# 1. Workload Identity not configured
.\aks-manager.ps1 setup-eso-wi

# 2. Secret names don't match Key Vault
# Verify secret names in Azure Key Vault match ExternalSecret specs

# 3. Force resync
kubectl delete secret games-api-secrets -n cloudgames
# ExternalSecrets controller will recreate it
```

### Issue: Pods in CrashLoopBackOff

**Symptoms:** Pods restart continuously

**Solution:**
```powershell
# Check logs (current crash)
kubectl logs -n cloudgames <pod-name> --tail=50

# Check logs from previous crash
kubectl logs -n cloudgames <pod-name> --previous

# Get full pod details
kubectl describe pod -n cloudgames <pod-name>

# Common causes:
# - Missing secrets → Check ExternalSecrets are synced
# - Database connection failure → Check connection string in Key Vault
# - Out of memory → Increase pod memory limits
# - Application error → Check application logs for specific error
```

### Issue: ArgoCD Applications Not Syncing

**Symptoms:** ArgoCD shows "OutOfSync" or "Unknown"

**Solution:**
```powershell
# Check ArgoCD controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=50

# Get application status
kubectl get applications -n argocd
kubectl describe application cloudgames-prod -n argocd

# Check Git repository connection
kubectl logs -n argocd deployment/argocd-repo-server --tail=50

# Manually recover sync
.\aks-manager.ps1 fix-argocd-sync
```

---

## 🚀 Common Workflows

### Update Workload Identity After Terraform Changes

If you recreate Azure Managed Identities via Terraform, you need to update the ServiceAccount annotations:

```powershell
# Standalone update (after terraform apply)
.\aks-manager.ps1 update-sa-client-ids

# This automatically:
# 1. Fetches client IDs: terraform output user_api_client_id, games_api_client_id, payments_api_client_id
# 2. Updates YAML files:
#    - infrastructure/kubernetes/base/user/service-account.yaml
#    - infrastructure/kubernetes/base/games/service-account.yaml
#    - infrastructure/kubernetes/base/payments/service-account.yaml
# 3. Shows next steps (commit changes, ArgoCD will sync)

# Commit the updated files
git add infrastructure/kubernetes/base/*/service-account.yaml
git commit -m "Update ServiceAccount client IDs after Terraform apply"
git push

# ArgoCD will automatically sync (or force sync)
kubectl apply -f infrastructure/kubernetes/base/user/service-account.yaml
kubectl apply -f infrastructure/kubernetes/base/games/service-account.yaml
kubectl apply -f infrastructure/kubernetes/base/payments/service-account.yaml
```

**Why this is needed:**
- Azure Managed Identities get unique `client_id` values
- Kubernetes ServiceAccounts need these IDs in `azure.workload.identity/client-id` annotations
- Workload Identity uses OIDC federation to link Azure AD identities to K8s ServiceAccounts
- Pods authenticate to Azure services (Key Vault, Service Bus) without secrets

### Deploy New Version of Application

```powershell
# Build and push new image to ACR
cd infrastructure/kubernetes/scripts/prod
.\aks-manager.ps1 build-push

# ArgoCD Image Updater automatically:
# 1. Detects new image in ACR
# 2. Creates/updates deployment manifest
# 3. Syncs to cluster (watch in ArgoCD UI)

# Check deployment status
kubectl rollout status deployment/games-api -n cloudgames
```

### Check for Component Updates

```powershell
# See available Helm chart updates (NGINX, ESO, etc.)
.\aks-manager.ps1 check-versions

# See available ArgoCD versions
.\aks-manager.ps1 check-argocd-updates

# Update a specific Helm chart
.\aks-manager.ps1 update-chart
# Follow prompts to select chart and target version
```

### View Component Logs

```powershell
# Via aks-manager (easier)
.\aks-manager.ps1 logs nginx    # NGINX Ingress Controller
.\aks-manager.ps1 logs eso      # External Secrets Operator
.\aks-manager.ps1 logs argocd   # ArgoCD

# Or use kubectl directly
kubectl logs -n argocd deployment/argocd-server -f
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f
```

### Auto-Detect & Fix Issues

```powershell
# Automatic diagnosis and repair of degraded components
.\aks-manager.ps1 diagnose-fix-components

# This will:
# ✅ Check all component health
# ✅ Restart failed pods
# ✅ Fix webhook certificate issues
# ✅ Recover NGINX ingress problems
# ✅ Reset stuck deployments
```

---

## ⚠️ Advanced: Cluster Reset

### When to Use Cluster Reset

Use `reset-cluster` only when you need a **completely clean installation** while keeping the AKS infrastructure:

- ❌ Complete reinstallation from scratch
- ❌ Remove all workloads and deployments  
- ❌ Start with fresh configuration
- ✅ Preserves: AKS cluster, networks, storage, RBAC

### Reset & Reinstall

```powershell
# ⚠️ WARNING: This DELETES all workloads!
.\aks-manager.ps1 reset-cluster

# Follow confirmation prompts carefully
# Wait for completion (5-10 minutes)

# After reset, do fresh setup:
.\aks-manager.ps1 post-terraform-setup

# Verify healthy cluster
.\aks-manager.ps1 status
```

### What Gets Deleted

```
❌ DELETED:
  - ArgoCD and all managed applications
  - NGINX Ingress Controller
  - External Secrets Operator
  - All workloads in cloudgames namespace
  - Custom monitoring (if installed)

✅ PRESERVED:
  - AKS cluster itself
  - Node pools & networking
  - Azure Key Vault & secrets
  - PostgreSQL databases
  - Service Bus
  - ACR & images
  - System namespaces (kube-system, default)
```

---

## 📚 Reference

### AKS Manager Commands

```powershell
# Connection & Status
.\aks-manager.ps1 connect                  # Get AKS credentials
.\aks-manager.ps1 status                   # Full cluster health check

# Installation
.\aks-manager.ps1 post-terraform-setup     # Complete one-shot setup (recommended)
.\aks-manager.ps1 bootstrap [env]          # Deploy applications via ArgoCD
.\aks-manager.ps1 build-push [api]         # Build & push images to ACR

# Configuration
.\aks-manager.ps1 setup-eso-wi             # Configure Workload Identity
.\aks-manager.ps1 update-sa-client-ids     # Update ServiceAccount client IDs from Terraform
.\aks-manager.ps1 configure-image-updater  # Enable automatic image updates
.\aks-manager.ps1 get-argocd-url           # Get ArgoCD access info

# Maintenance & Troubleshooting
.\aks-manager.ps1 logs [component]         # View logs (nginx/eso/argocd)
.\aks-manager.ps1 check-versions           # Check Helm chart updates
.\aks-manager.ps1 check-argocd-updates     # Check ArgoCD version
.\aks-manager.ps1 update-chart             # Update Helm chart version
.\aks-manager.ps1 diagnose-fix-components  # Auto-detect & fix issues
.\aks-manager.ps1 fix-argocd-sync          # Recover sync failures
.\aks-manager.ps1 cleanup-audit            # Analyze unused resources

# Advanced/Dangerous
.\aks-manager.ps1 reset-cluster            # ⚠️ Delete all workloads
.\aks-manager.ps1 force-delete-namespace   # Force delete stuck namespace

# Help
.\aks-manager.ps1 help                     # Show all commands
.\aks-manager.ps1 menu                     # Interactive menu
```

### Key Azure Resources

| Resource | Purpose | Created by |
|----------|---------|-----------|
| AKS Cluster | Kubernetes infrastructure | Terraform |
| ACR | Container image registry | Terraform |
| Key Vault | Secrets management | Terraform |
| PostgreSQL | Application databases | Terraform |
| Service Bus | Messaging (event-driven) | Terraform |
| Workload Identity | Passwordless authentication | post-terraform-setup |
| External Secrets | K8s ↔ Key Vault sync | post-terraform-setup |
| ArgoCD | GitOps deployments | post-terraform-setup |

### Default Credentials

| Component | Default User | Location |
|-----------|--------------|----------|
| ArgoCD | admin | From `argocd-initial-admin-secret` |
| NGINX | N/A | LoadBalancer IP in Azure |
| Key Vault | Managed Identity | Workload Identity configuration |

### Kubernetes Namespaces

| Namespace | Purpose |
|-----------|---------|
| `argocd` | ArgoCD GitOps platform |
| `ingress-nginx` | NGINX Ingress Controller |
| `external-secrets` | ESO & secret syncing |
| `cloudgames` | Application deployments |
| `kube-system` | Kubernetes system components |

---

### Getting Help

For detailed help with specific commands:
```powershell
.\aks-manager.ps1 help          # Show all available commands
.\aks-manager.ps1              # Interactive menu with guided options
```

For component-specific documentation, check ARCHITECTURE.md.
