# 🚀 CloudGames AKS - Complete Installation Guide

> **Complete guide for setting up AKS infrastructure after Terraform provisioning**

## 📖 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Quick Start - Automated Setup](#-quick-start---automated-setup)
3. [Manual Step-by-Step Setup](#-manual-step-by-step-setup)
4. [Component Installation Details](#-component-installation-details)
5. [Post-Installation Verification](#-post-installation-verification)
6. [Troubleshooting](#-troubleshooting)
7. [Cost Optimization](#-cost-optimization)

---

## 📋 Prerequisites

**Required Tools:**
- ✅ Terraform apply completed successfully (Azure infrastructure provisioned)
- ✅ Azure CLI installed and authenticated (`az login`)
- ✅ kubectl installed (Kubernetes CLI)
- ✅ Helm v3 installed (Kubernetes package manager)
- ✅ Access to the AKS cluster

**Azure Resources (Created by Terraform):**
- Azure Kubernetes Service (AKS) cluster
- Azure Key Vault with secrets
- Azure Container Registry (ACR)
- Azure Service Bus (for messaging)
- Azure API Management (APIM) - requires backend configuration

**Important:** This guide assumes Terraform has already provisioned the Azure infrastructure. These steps configure Kubernetes-specific components that require cluster access.

---

## ⚡ Quick Start - Automated Setup

### Option 1: Complete Automated Setup (Recommended)

Use the centralized `aks-manager.ps1` script for automated installation:

```powershell
cd infrastructure/kubernetes/scripts/prod

# Interactive menu
.\aks-manager.ps1

# Or use command line
.\aks-manager.ps1 post-terraform-setup
```

**What it does automatically:**
1. ✅ Connects to AKS cluster
2. ✅ Installs NGINX Ingress Controller
3. ✅ Obtains LoadBalancer IP
4. ✅ Updates Terraform variables with NGINX IP
5. ✅ Re-runs Terraform to configure APIM backends
6. ✅ Installs External Secrets Operator (ESO)
7. ✅ Configures Workload Identity
8. ✅ Installs Grafana Agent (optional)
9. ✅ Deploys applications via Kustomize

**Estimated time:** 10-15 minutes

### Option 2: Individual Component Installation

```powershell
cd infrastructure/kubernetes/scripts/prod

# Use the manager script
.\aks-manager.ps1

# Then select from menu:
# [1] Connect to AKS cluster
# [3] Install ArgoCD
# [4] Install Grafana Agent
# [5] Install External Secrets Operator
# [6] Install NGINX Ingress
# [14] Post-Terraform Complete Setup
```

---

## 🔧 Manual Step-by-Step Setup

### Step 1: Connect to AKS Cluster

```powershell
# Get AKS credentials
az aks get-credentials `
  --resource-group tc-cloudgames-solution-dev-rg `
  --name tc-cloudgames-dev-cr8n-aks `
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

**Expected output:**
```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-12345678-vmss000000   Ready    agent   1d    v1.28.x
```

---

### Step 2: Install NGINX Ingress Controller

**Why NGINX Ingress?**
- **Cost Savings:** Single LoadBalancer ($40/month) vs multiple LoadBalancers ($120/month)
- **Centralized Routing:** Route all APIs through one public IP
- **TLS/SSL Management:** Centralized certificate management
- **Rate Limiting & CORS:** Built-in traffic control

**Installation:**

```powershell
cd infrastructure/kubernetes/scripts/prod

# Install NGINX Ingress
.\install-nginx-ingress-aks.ps1 `
  -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks" `
  -Namespace "ingress-nginx" `
  -ChartVersion "4.11.3"
```

**Wait for LoadBalancer IP (2-3 minutes):**

```powershell
# Watch until EXTERNAL-IP appears
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch

# Get the IP
$NGINX_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "NGINX Ingress IP: $NGINX_IP" -ForegroundColor Green
```

---

### Step 3: Update Terraform with NGINX IP

**Why this step?**  
Azure API Management (APIM) needs the NGINX Ingress IP to route traffic to backend APIs. Since Terraform Cloud cannot access the Kubernetes cluster, we install NGINX manually and then update Terraform variables.

```powershell
cd infrastructure/terraform/foundation

# Add NGINX IP to terraform.tfvars
@"
nginx_ingress_ip = "$NGINX_IP"
"@ | Add-Content terraform.tfvars

# Re-run Terraform to update APIM backends
terraform plan -out=tfplan
terraform apply tfplan
```

**What changes:**
- APIM backend URLs updated: `http://<NGINX_IP>`
- APIM APIs now route to Kubernetes services via NGINX

---

### Step 4: Install External Secrets Operator (ESO)

**Why ESO?**
- ❌ **Without ESO:** Hardcoded secrets or manual secret creation
- ✅ **With ESO:** Automatic sync from Azure Key Vault
- 🔄 Dynamic secret updates (no pod restart needed)
- 🔐 Azure Workload Identity for passwordless auth

**Installation:**

```powershell
cd infrastructure/kubernetes/scripts/prod

# Install ESO
.\install-external-secrets-aks.ps1 `
  -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks"

# Configure Workload Identity (recommended)
.\setup-eso-workload-identity.ps1 `
  --resourceGroup tc-cloudgames-solution-dev-rg `
  --clusterName tc-cloudgames-dev-cr8n-aks
```

**How it works:**

```yaml
# ExternalSecret automatically syncs from Key Vault
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: games-api-secrets
spec:
  secretStoreRef:
    name: azure-keyvault
  target:
    name: games-api-secrets
  data:
  - secretKey: ConnectionStrings__DefaultConnection
    remoteRef:
      key: connection-string-postgresql  # Key Vault secret name
```

**Verify:**

```powershell
kubectl get externalsecrets -n cloudgames
kubectl get secrets -n cloudgames
```

---

### Step 5: Install Grafana Agent (Optional)

**Why Grafana Agent?**
- 📊 Collects metrics, logs, and traces
- 📈 Sends to Grafana Cloud for visualization
- 🔔 Alerts on errors/downtime
- 🐛 Centralized troubleshooting

```powershell
cd infrastructure/kubernetes/scripts/prod

.\install-grafana-agent-aks.ps1 `
  -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks"
```

---

### Step 6: Deploy Applications

**Option A: Via Kustomize (Direct)**

```powershell
# Apply production overlay
kubectl apply -k infrastructure/kubernetes/overlays/prod

# Wait for pods to be ready
kubectl get pods -n cloudgames --watch
```

**Option B: Via ArgoCD (GitOps)**

```powershell
cd infrastructure/kubernetes/scripts/prod

# Install ArgoCD
.\install-argocd-aks.ps1 `
  -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks"

# Bootstrap production apps
.\aks-manager.ps1 bootstrap prod
```

**ArgoCD Access:**

```powershell
# Get ArgoCD URL
.\aks-manager.ps1 get-argocd-url

# Default credentials:
# Username: admin
# Password: Argo@AKS123!
```

---

## 📦 Component Installation Details

### ArgoCD (GitOps Controller)

```powershell
.\aks-manager.ps1 install-argocd
```

**Features:**
- Manages deployments via Git (declarative)
- Applies Kubernetes manifests automatically
- Synchronizes desired state vs current state
- Web UI for deployment visualization

**Idempotent:** ✅ Prompts for reinstall if already exists

---

### External Secrets Operator (ESO)

```powershell
.\aks-manager.ps1 install-eso
```

**Features:**
- Automatically syncs secrets from Azure Key Vault
- Uses Workload Identity for authentication
- No hardcoded credentials
- Dynamic secret updates

**Setup after installation:**

```powershell
# Configure with Workload Identity (recommended)
.\aks-manager.ps1 setup-eso-wi

# Or legacy ClusterSecretStore
.\aks-manager.ps1 setup-eso
```

**How secrets flow:**

```
Azure Key Vault
    ↓ (via Workload Identity)
External Secrets Operator
    ↓ (creates)
Kubernetes Secrets
    ↓ (consumed by)
Application Pods
```

**Idempotent:** ✅ Prompts for reinstall if already exists

---

### NGINX Ingress Controller

```powershell
.\aks-manager.ps1 install-nginx
```

**Features:**
- Single LoadBalancer for all services (cost savings)
- HTTP/HTTPS routing by domain/path
- TLS/SSL certificate management
- Rate limiting, CORS, custom headers

**Cost comparison:**

```
❌ Without NGINX:
- users-api LoadBalancer: $40/month
- games-api LoadBalancer: $40/month
- payments-api LoadBalancer: $40/month
Total: $120/month

✅ With NGINX:
- NGINX LoadBalancer: $40/month
Total: $40/month
💰 Savings: $80/month (67%)
```

**Routing example:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cloudgames-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: api.cloudgames.com
    http:
      paths:
      - path: /users
        pathType: Prefix
        backend:
          service:
            name: user-api
            port:
              number: 80
      - path: /games
        pathType: Prefix
        backend:
          service:
            name: games-api
            port:
              number: 80
```

**Idempotent:** ✅ Prompts for reinstall if already exists

---

### Grafana Agent

```powershell
.\aks-manager.ps1 install-grafana-agent
```

**Features:**
- Collects metrics (Prometheus format)
- Collects logs (Loki format)
- Collects traces (Tempo/OTLP format)
- Sends to Grafana Cloud

**What it monitors:**
- API response times
- Error rates
- Resource usage (CPU, memory)
- Database connection pool
- Custom application metrics

**Idempotent:** ✅ Prompts for reinstall if already exists

---

## ✅ Post-Installation Verification

### Check Pods Status

```powershell
kubectl get pods -n cloudgames -o wide
```

**Expected status:**
- `games-api`: 2 replicas Running (1/1 Ready, 0 restarts)
- `user-api`: 1 replica Running (1/1 Ready, 0 restarts)
- `payments-api`: 1 replica Running (1/1 Ready, 0 restarts)

**Resource allocations:**
- Memory: 512Mi request / 1Gi limit
- CPU: 500m limit
- Readiness probe: 10s initial delay

---

### Check Secrets Synchronization

```powershell
# Check ExternalSecrets
kubectl get externalsecrets -n cloudgames

# Check created Kubernetes secrets
kubectl get secrets -n cloudgames

# Verify secret data (base64 encoded)
kubectl get secret games-api-secrets -n cloudgames -o jsonpath='{.data}' | jq
```

**Expected ExternalSecrets:**
- `games-api-secrets` → Synced
- `user-api-secrets` → Synced
- `payments-api-secrets` → Synced

---

### Check Ingress

```powershell
# Get Ingress resources
kubectl get ingress -n cloudgames

# Get NGINX LoadBalancer IP
$NGINX_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "NGINX IP: $NGINX_IP"
```

---

### Test Endpoints

```powershell
# Get NGINX IP
$NGINX_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test health endpoints
curl "http://$NGINX_IP/health" -H "Host: games-api.cloudgames.local"
curl "http://$NGINX_IP/health" -H "Host: user-api.cloudgames.local"
curl "http://$NGINX_IP/health" -H "Host: payments-api.cloudgames.local"
```

**Expected response:**
```json
{
  "status": "Healthy",
  "checks": {
    "database": "Healthy",
    "redis": "Healthy"
  }
}
```

---

### Check Component Status

```powershell
# Use aks-manager for overview
.\aks-manager.ps1 status

# Or check individually
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
kubectl get pods -n external-secrets
kubectl get pods -n grafana-agent
```

---

## 🐛 Troubleshooting

### NGINX Ingress not receiving IP

```powershell
# Check controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50

# Check service
kubectl describe svc -n ingress-nginx ingress-nginx-controller

# Check events
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'
```

**Common issues:**
- Azure LoadBalancer quota exceeded
- Network policy blocking traffic
- Service principal permissions

---

### Pods in CrashLoopBackOff

```powershell
# Check current logs
kubectl logs -n cloudgames <pod-name>

# Check previous logs (after crash)
kubectl logs -n cloudgames <pod-name> --previous

# Check pod events
kubectl describe pod -n cloudgames <pod-name>
```

**Common causes:**
- Missing secrets (check ExternalSecrets)
- Database connection failure
- Insufficient memory (OOMKilled)
- Application startup error

---

### External Secrets not syncing

```powershell
# Check ClusterSecretStore
kubectl get clustersecretstore -o yaml

# Check ESO logs
kubectl logs -n external-secrets deployment/external-secrets -f

# Check ExternalSecret status
kubectl describe externalsecret -n cloudgames <name>
```

**Common issues:**
- Workload Identity not configured
- Key Vault permissions missing
- Secret name mismatch in Key Vault
- Network connectivity to Key Vault

**Force resync:**

```powershell
# Delete secret (will be recreated automatically)
kubectl delete secret -n cloudgames games-api-secrets

# Wait 10-15 seconds
kubectl get externalsecrets -n cloudgames --watch
```

---

### Database connection failures

```powershell
# Check connection string in secret
kubectl get secret games-api-secrets -n cloudgames -o jsonpath='{.data.ConnectionStrings__DefaultConnection}' | base64 --decode

# Check database connectivity from pod
kubectl exec -n cloudgames <pod-name> -- nslookup <database-host>

# Check firewall rules in Azure Portal
az postgres flexible-server firewall-rule list --resource-group <rg> --name <db-name>
```

**Fixes:**
- Update Key Vault secret if connection string is wrong
- Add AKS cluster IP to database firewall rules
- Verify database is running and accessible

---

### ArgoCD application not syncing

```powershell
# Check application status
kubectl get application cloudgames-prod -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=50

# Force sync via CLI
argocd app sync cloudgames-prod

# Or via UI
.\aks-manager.ps1 get-argocd-url
# Then click "Sync" in the web UI
```

---

## 💰 Cost Optimization

### Resource Allocations (Optimized)

| API | Replicas | CPU Request | Memory Request | Memory Limit |
|-----|----------|-------------|----------------|--------------|
| **games-api** | 2 | 500m | 512Mi | 1Gi |
| **user-api** | 1 | 500m | 512Mi | 1Gi |
| **payments-api** | 1 | 500m | 512Mi | 1Gi |

**Why these values:**
- **512Mi request:** Prevents OOMKilled errors
- **1Gi limit:** Allows spikes during high traffic
- **2 replicas for games-api:** Distributes load, prevents downtime
- **Readiness delay 10s:** Gives app time to initialize

---

### Database Connection Pool (Optimized)

```
DB_MAX_POOL_SIZE=20      (was 5)
DB_MIN_POOL_SIZE=2       (was 0)
DB_CONNECTION_TIMEOUT=60 (was 30)
```

**Impact:**
- ✅ Prevents "connection pool exhausted" errors
- ✅ Faster response under load
- ✅ Reduces intermittent 502 errors

---

### NGINX Ingress Savings

```
Monthly cost breakdown:
- 3 LoadBalancers without NGINX: $120/month
- 1 LoadBalancer with NGINX: $40/month
💰 Savings: $80/month (67% reduction)
```

---

### Auto-Scaling (Optional)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: games-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: games-api
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Benefits:**
- Automatically scales based on CPU/memory
- Cost-efficient during low traffic
- Handles traffic spikes gracefully

---

## 📝 Important Notes

1. **Order is critical:** Terraform → NGINX → Update Terraform → ESO → Apps
2. **NGINX IP required:** Needed for APIM backend configuration
3. **Workload Identity:** Passwordless authentication to Key Vault
4. **Resource limits:** Configured for stability (512Mi/1Gi memory)
5. **games-api replicas:** Runs with 2 replicas for load distribution

---

## 🔄 Complete Installation Flow

```powershell
# 1. Terraform (Azure infrastructure)
cd infrastructure/terraform/foundation
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 2. Post-Terraform Kubernetes setup (AUTOMATED)
cd ../../kubernetes/scripts/prod
.\aks-manager.ps1 post-terraform-setup

# Or manual step-by-step:
.\aks-manager.ps1 connect                    # Connect to AKS
.\aks-manager.ps1 install-nginx              # Install NGINX Ingress
$NGINX_IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
cd ../../../terraform/foundation
"nginx_ingress_ip = `"$NGINX_IP`"" | Add-Content terraform.tfvars
terraform apply -auto-approve                # Update APIM
cd ../../kubernetes/scripts/prod
.\aks-manager.ps1 install-eso                # Install External Secrets
.\aks-manager.ps1 setup-eso-wi               # Configure Workload Identity
kubectl apply -k ../../overlays/prod         # Deploy apps

# 3. Verify
kubectl get pods -n cloudgames --watch
```

---

## 🔗 References

- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [External Secrets Operator](https://external-secrets.io/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/)
- [Terraform Cloud](https://app.terraform.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Grafana Agent](https://grafana.com/docs/agent/)

---

## 📞 Support

For issues or questions:
1. Check [Troubleshooting](#-troubleshooting) section
2. View component logs: `.\aks-manager.ps1 logs <component>`
3. Check cluster status: `.\aks-manager.ps1 status`
4. Review Azure Portal for infrastructure issues

---

✅ **Installation complete! Your CloudGames AKS cluster is ready for production.**
