# 🚀 Installation Guide - CloudGames AKS

## 📋 Recommended Installation Order

### 1️⃣ **ArgoCD** (GitOps Controller)
```powershell
.\aks-manager.ps1 install-argocd
```

**What it does:**
- Installs ArgoCD via Helm
- Configures LoadBalancer with public IP
- Sets admin password: `Argo@AKS123!`

**Why first:**
- Manages deployments via Git (declarative)
- Applies Kubernetes manifests automatically
- Synchronizes desired state vs current state

**Idempotent:** ✅ If already exists, prompts to reinstall

---

### 2️⃣ **External Secrets Operator (ESO)** (Secrets Manager)
```powershell
.\aks-manager.ps1 install-eso
```

**What it does:**
- Installs ESO via Helm
- Configures CRDs (ExternalSecret, SecretStore)
- Prepares integration with Azure Key Vault

**Why ESO:**
- ❌ **Without ESO:** Hardcoded secrets or via Terraform (static)
- ✅ **With ESO:** Automatically syncs from Key Vault
- Managed Identity/RBAC authenticates ESO to Key Vault
- Dynamic secret updates (no redeploy needed)

**Usage example:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: azure-keyvault
  target:
    name: db-secret
  data:
  - secretKey: password
    remoteRef:
      key: database-password  # Name in Key Vault
```

**Idempotent:** ✅ If already exists, prompts to reinstall

---

### 3️⃣ **NGINX Ingress Controller** (Traffic Routing)
```powershell
.\aks-manager.ps1 install-nginx
```

**What it does:**
- Installs NGINX Ingress via Helm
- Creates LoadBalancer with single public IP
- Manages HTTP/HTTPS routing

**Why NGINX:**
- **Without NGINX:** Each service needs LoadBalancer ($30-50/month each)
- **With NGINX:** 1 LoadBalancer for ALL services ($30-50/month total)
- Routing by domain/path: `api.cloudgames.com/users`, `/games`, `/payments`
- Centralized TLS/SSL (Let's Encrypt)
- Rate limiting, CORS, custom headers

**Cost savings:**
```
Without NGINX:
- users-api LoadBalancer: $40/month
- games-api LoadBalancer: $40/month
- payms-api LoadBalancer: $40/month
Total: $120/month

With NGINX:
- NGINX LoadBalancer: $40/month
Total: $40/month
Savings: $80/month (67%)
```

**Idempotent:** ✅ If already exists, prompts to reinstall

---

### 4️⃣ **Grafana Agent** (Observability)
```powershell
.\aks-manager.ps1 install-grafana-agent
```

**What it does:**
- Installs Grafana Agent via Helm
- Collects metrics, logs, traces
- Sends to Grafana Cloud

**Why Grafana Agent:**
- Monitors API performance
- Alerts on errors/downtime
- Centralized log analysis
- Quick troubleshooting

**Idempotent:** ✅ If already exists, prompts to reinstall

---

### 5️⃣ **Build & Push Images** (Docker to ACR)
```powershell
.\aks-manager.ps1 build-push
# Choose: all, user, games, or payments
```

**What it does:**
- Builds Docker images for APIs (.NET)
- Pushes to Azure Container Registry (ACR)
- Configurable tag (default: `dev`)

**Available APIs:**
- `users-api`: Authentication, users
- `games-api`: Game catalog
- `payms-api`: Payment processing

**ACR example:**
```
tccloudgamesdevcr8nacr.azurecr.io/users-api:dev
tccloudgamesdevcr8nacr.azurecr.io/games-api:dev
tccloudgamesdevcr8nacr.azurecr.io/payms-api:dev
```

---

### 6️⃣ **Bootstrap ArgoCD Applications** (Deploy via GitOps)
```powershell
.\aks-manager.ps1 bootstrap dev
```

**What it does:**
- Applies ArgoCD Application manifests
- ArgoCD syncs Git repository
- Automatic deployment of users-api, games-api, payms-api

**Result:**
- Pods running in `cloudgames` namespace
- Services exposed via NGINX Ingress
- Secrets synchronized from Key Vault via ESO

---

## 🎯 Complete Installation Script (Correct Order)

```powershell
# 1. Connect to cluster
.\aks-manager.ps1 connect

# 2. Check status
.\aks-manager.ps1 status

# 3. Install components (ORDER IMPORTANT)
.\aks-manager.ps1 install-argocd          # GitOps
.\aks-manager.ps1 install-eso             # Secrets from Key Vault
.\aks-manager.ps1 install-nginx           # Ingress/Routing
.\aks-manager.ps1 install-grafana-agent   # Observability

# Or install all at once:
.\aks-manager.ps1 install-all

# 4. Build and push images
.\aks-manager.ps1 build-push

# 5. Deploy via ArgoCD
.\aks-manager.ps1 bootstrap dev

# 6. Check ArgoCD URL
.\aks-manager.ps1 get-argocd-url
```

---

## ✅ Script Features (Idempotency)

All scripts are now **idempotent**:

1. **Detects if installation already exists**
2. **Prompts for reinstall:** `Do you want to REINSTALL? (y/N)`
3. **Behavior:**
   - `y` or `Y`: Completely removes and reinstalls
   - Any other key: Exits without changes
   - Enter (empty): Exits without changes

**Example:**
```powershell
.\aks-manager.ps1 install-argocd

# If already exists:
⚠️  ArgoCD is already installed in namespace 'argocd'

Do you want to REINSTALL ArgoCD? This will DELETE and recreate it. (y/N)
> n

ℹ️  Installation cancelled. Existing ArgoCD installation preserved.
```

---

## 🔑 Secrets Management Flow

```
Key Vault (Azure)
    ↓
ESO + Managed Identity (RBAC)
    ↓
Kubernetes Secrets (auto-sync)
    ↓
Pods (secretRef)
```

**No manual intervention!**

---

## 🌐 Ingress Routing Example

```yaml
# After NGINX is installed
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
      - path: /payments
        pathType: Prefix
        backend:
          service:
            name: payments-api
            port:
              number: 80
```

**Result:**
- `http://api.cloudgames.com/users` → user-api
- `http://api.cloudgames.com/games` → games-api
- `http://api.cloudgames.com/payments` → payms-api

**Single public IP!**

---

## 📊 Updated Menu

```
[1] Connect to AKS cluster
[2] Show cluster status
[3] Install ArgoCD
[4] Install Grafana Agent
[5] Install External Secrets Operator
[6] Install NGINX Ingress
[7] Install ALL components
[8] Get ArgoCD URL & credentials
[9] Bootstrap ArgoCD apps
[10] Build & Push images to ACR
[11] View logs
[0] Exit
```

**Removed:** Separate reset item (now integrated into install)

---

## 🛠️ Troubleshooting

### View component logs:
```powershell
.\aks-manager.ps1 logs argocd
.\aks-manager.ps1 logs eso
.\aks-manager.ps1 logs nginx
.\aks-manager.ps1 logs grafana-agent
```

### Reinstall problematic component:
```powershell
# Script detects existing installation and prompts for reinstall
.\aks-manager.ps1 install-argocd
> y  # Confirm reinstallation
```

### Build specific API:
```powershell
.\aks-manager.ps1 build-push user    # Only users-api
.\aks-manager.ps1 build-push games   # Only games-api
```

---

## 🎯 Next Steps (CI/CD)

After manual validation, automate with GitHub Actions:

```yaml
name: Build and Deploy
on:
  push:
    branches: [main, develop]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/docker-login@v1
        with:
          login-server: tccloudgamesdevcr8nacr.azurecr.io
      
      - name: Build and push
        run: |
          docker build -t $ACR_REGISTRY/users-api:${{ github.sha }} .
          docker push $ACR_REGISTRY/users-api:${{ github.sha }}
      
      - name: Update ArgoCD manifest
        run: |
          # Update image tag in Git repository
          # ArgoCD auto-syncs and deploys
```

---

## 📝 Installation Checklist

- [ ] Connect to AKS: `.\aks-manager.ps1 connect`
- [ ] Install ArgoCD: `.\aks-manager.ps1 install-argocd`
- [ ] Install ESO: `.\aks-manager.ps1 install-eso`
- [ ] Install NGINX: `.\aks-manager.ps1 install-nginx`
- [ ] Install Grafana: `.\aks-manager.ps1 install-grafana-agent`
- [ ] Build images: `.\aks-manager.ps1 build-push`
- [ ] Bootstrap apps: `.\aks-manager.ps1 bootstrap dev`
- [ ] Check status: `.\aks-manager.ps1 status`
- [ ] Access ArgoCD: `.\aks-manager.ps1 get-argocd-url`

✅ **Ready for production!**
