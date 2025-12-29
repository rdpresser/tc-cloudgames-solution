# ☸️ TC CloudGames - Kubernetes Infrastructure

> Complete Kubernetes infrastructure for **local development (K3D)** and **production (AKS)**

---

## 📚 Documentation

| Environment | Description | Documentation |
|-------------|-------------|---------------|
| **🔧 Local Development** | K3D cluster with native Ingress | This README (below) |
| **☁️ Production (AKS)** | Azure Kubernetes Service | [scripts/prod/README.md](scripts/prod/README.md) |

**Quick Links:**
- 🏗️ [AKS Architecture](scripts/prod/ARCHITECTURE.md) - Modular script architecture
- 📊 [Grafana Cloud Setup](scripts/prod/GRAFANA_CLOUD_SETUP.md) - Monitoring configuration
- 🚀 [AKS Quick Start](scripts/prod/README.md#-quick-start) - Get started with production

---

# 🚀 K3D Local Development

> Complete local Kubernetes development environment with **native Ingress support** - no port-forward needed!

## ⚡ Quick Start

```powershell
# Interactive menu
cd infrastructure\kubernetes\scripts
.\k3d-manager.ps1

# Direct commands
.\k3d-manager.ps1 create
.\k3d-manager.ps1 status
```

## ✨ Native Ingress Feature

This cluster is configured with **native port mapping** (`-p 80:80@loadbalancer`), which means:
- ✅ **No port-forward needed** for accessing ArgoCD and APIs
- ✅ Works just like a real cluster (AKS/EKS)
- ✅ Add to hosts file once: `127.0.0.1 argocd.local cloudgames.local`
- ✅ Access directly: `http://argocd.local`, `http://cloudgames.local/user`, `/games`, `/payments`

### Setup (One-time) - REQUIRED

Run as Administrator to add DNS entries:
```powershell
.\k3d-manager.ps1 update-hosts
```

Or manually add to `C:\Windows\System32\drivers\etc\hosts`:
```
127.0.0.1 argocd.local
127.0.0.1 cloudgames.local
```

---

## 🎯 Complete Setup Flow

> **IMPORTANT**: Follow this order when setting up the local environment.

```
1. .\k3d-manager.ps1 create              # Create cluster (ArgoCD, KEDA, Prometheus, Grafana)
       ↓
2. .\k3d-manager.ps1 update-hosts        # Add DNS entries (run as Administrator)
       ↓
3. .\k3d-manager.ps1 external-secrets    # Install ESO + configure Azure Key Vault
       ↓
4. .\k3d-manager.ps1 bootstrap           # Deploy apps via ArgoCD
       ↓
5. .\k3d-manager.ps1 port-forward grafana  # (Optional) Port-forward for Grafana only
```

### After Reboot
```powershell
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward grafana   # Only if you need Grafana
```

### Status & Monitoring
```powershell
.\k3d-manager.ps1 status
.\k3d-manager.ps1 list
.\k3d-manager.ps1 secrets
```

---

## 🔗 Service Access

### Native Ingress (NO port-forward needed!)
| Service | URL | Credentials | Setup |
|---------|-----|-------------|-------|
| ArgoCD | http://argocd.local | admin / Argo@123 | `.\k3d-manager.ps1 update-hosts` |
| User API | http://cloudgames.local/user | - | Hosts file required |
| Games API | http://cloudgames.local/games | - | Hosts file required |
| Payments API | http://cloudgames.local/payments | - | Hosts file required |

### Management Services (require port-forward)
| Service | URL | Credentials | Command |
|---------|-----|-------------|---------|
| Grafana | http://localhost:3000 | rdpresser / rdpresser@123 | `.\k3d-manager.ps1 port-forward grafana` |
| Headlamp | http://localhost:4466 | kubeconfig | `.\k3d-manager.ps1 headlamp` |

---

## 📦 Scripts Overview

### Core Scripts
| Script | Description |
|--------|-------------|
| `k3d-manager.ps1` | Main entry point - interactive menu + CLI |
| `create-all-from-zero.ps1` | Full cluster build (registry, ArgoCD, KEDA, Prometheus+Grafana) |
| `start-cluster.ps1` | Start existing cluster after reboot |
| `cleanup-all.ps1` | Remove everything (cluster + registry) |

### Port-Forward Scripts
| Script | Description |
|--------|-------------|
| `port-forward.ps1` | Start port-forward for Grafana (localhost:3000) |
| `stop-port-forward.ps1` | Stop Grafana port-forward |
| `list-port-forward.ps1` | List active port-forwards |

### Azure Integration
| Script | Description |
|--------|-------------|
| `setup-external-secrets.ps1` | Configure External Secrets Operator with Azure Key Vault |
| `list-secrets.ps1` | List, search, and inspect Kubernetes secrets |

### Deployment
| Script | Description |
|--------|-------------|
| `bootstrap-argocd-apps.ps1` | Bootstrap ArgoCD applications (dev/prod) |
| `reset-argocd-app.ps1` | Reset ArgoCD application (clear cache and recreate) |

### Utilities
| Script | Description |
|--------|-------------|
| `check-docker-network.ps1` | Diagnose Docker/network issues |
| `update-hosts-file.ps1` | Add argocd.local and cloudgames.local to hosts file (requires Admin) |
| `start-headlamp-docker.ps1` | Start Headlamp UI container |

---

## 🔐 External Secrets - Azure Key Vault Integration

This project uses [External Secrets Operator](https://external-secrets.io/) to synchronize secrets from Azure Key Vault with Kubernetes.

### Architecture

```
Azure Key Vault
      │
      ▼
┌─────────────────────┐
│ ClusterSecretStore  │  ← Connection configuration to Key Vault
│  (azure-keyvault)   │
└─────────────────────┘
      │
      ▼
┌─────────────────────┐
│  ExternalSecret     │  ← Defines which secrets to sync
│  (user-api-secrets) │
└─────────────────────┘
      │
      ▼
┌─────────────────────┐
│  Kubernetes Secret  │  ← Automatically created secret
│  (user-api-secrets) │
└─────────────────────┘
      │
      ▼
┌─────────────────────┐
│    Deployment       │  ← Pod consumes secret via envFrom
│    (user-api)       │
└─────────────────────┘
```

### Security Notes

| Data | Sensitive? | Can be in Git? | Explanation |
|------|------------|----------------|-------------|
| **tenantId** | ❌ No | ✅ Yes | Public Azure AD identifier |
| **clientId** | ⚠️ Semi-public | ✅ Yes | Like a "username", alone doesn't grant access |
| **clientSecret** | ✅ **YES!** | ❌ **NEVER** | This is the critical credential! |

The `clientSecret` is requested interactively by `setup-external-secrets.ps1` and is **never** saved to files or Git.

### Required Secrets in Azure Key Vault

<details>
<summary>📋 Click to expand full secrets list</summary>

#### Database
- `db-host`, `db-port`, `db-admin-login`, `db-password`
- `db-name-users`, `db-name-games`, `db-name-payments`
- `db-name-maintenance`, `db-schema`, `db-connection-timeout`

#### Cache (Redis)
- `cache-host`, `cache-port`, `cache-password`
- `cache-secure`, `cache-users-instance-name`

#### Service Bus
- `servicebus-connection-string`, `servicebus-namespace`
- `servicebus-auto-provision`, `servicebus-max-delivery-count`
- `servicebus-enable-dead-lettering`, `servicebus-auto-purge-on-startup`
- `servicebus-use-control-queues`
- `servicebus-users-topic-name`, `servicebus-games-topic-name`, `servicebus-payments-topic-name`

#### Grafana / OpenTelemetry
- `grafana-logs-api-token`, `grafana-otel-prometheus-api-token`
- `grafana-otel-users-resource-attributes`
- `grafana-otel-exporter-endpoint`, `grafana-otel-exporter-protocol`
- `grafana-otel-auth-header`

</details>

### Synchronization

- **Interval**: Secrets are synchronized every 1 hour (`refreshInterval: 1h`)
- **Automatic**: Any changes in Key Vault are reflected on the next refresh
- **Secure**: Secrets are never stored in Git

### Manual Setup (Alternative)

<details>
<summary>📋 Click to expand manual setup instructions</summary>

#### 1. Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true
```

#### 2. Create Service Principal for Key Vault access

```bash
# Create Service Principal
az ad sp create-for-rbac --name "external-secrets-k8s" --skip-assignment

# Save the output:
# {
#   "appId": "<CLIENT_ID>",
#   "password": "<CLIENT_SECRET>",
#   "tenant": "<TENANT_ID>"
# }

# Grant read permissions to Key Vault
az keyvault set-policy --name <KEY_VAULT_NAME> \
  --spn <CLIENT_ID> \
  --secret-permissions get list
```

#### 3. Create Secret with Azure credentials in the cluster

```bash
kubectl create namespace external-secrets

kubectl create secret generic azure-sp-credentials \
  -n external-secrets \
  --from-literal=clientId=<CLIENT_ID> \
  --from-literal=clientSecret=<CLIENT_SECRET>
```

</details>

---

## 🏗️ Build & Deploy Applications

### Build & Push Images
```powershell
cd <repository-root>

# Build
docker build -t user-api:dev     -f services\users\src\Adapters\Inbound\TC.CloudGames.Users.Api\Dockerfile .
docker build -t games-api:dev    -f services\games\src\Adapters\Inbound\TC.CloudGames.Games.Api\Dockerfile .
docker build -t payments-api:dev -f services\payments\src\Adapters\Inbound\TC.CloudGames.Payments.Api\Dockerfile .

# Tag for k3d registry
docker tag user-api:dev     localhost:5000/user-api:dev
docker tag games-api:dev    localhost:5000/games-api:dev
docker tag payments-api:dev localhost:5000/payments-api:dev

# Push
docker push localhost:5000/user-api:dev
docker push localhost:5000/games-api:dev
docker push localhost:5000/payments-api:dev
```

### Alternate: Import images (no registry pull)
```powershell
k3d image import user-api:dev games-api:dev payments-api:dev -c dev
kubectl rollout restart deployment user-api     -n cloudgames-dev
kubectl rollout restart deployment games-api    -n cloudgames-dev
kubectl rollout restart deployment payments-api -n cloudgames-dev
```

### Deploy via ArgoCD (App of Apps Pattern)
```powershell
kubectl apply -f manifests/application-bootstrap.yaml

# Verify
kubectl get applications -n argocd
kubectl get pods -n cloudgames-dev
```

**ArgoCD Web UI**: http://argocd.local (admin / Argo@123)

---

### Production (AKS) – Argo CD via YAML

Argo CD on AKS can be installed using YAML with a configurable namespace (avoids Terraform/Helm needing direct cluster access):

```powershell
cd infrastructure\kubernetes\scripts\prod

# Install Argo CD in the default namespace
./aks-manager.ps1 install-argocd

# Or install into a different namespace (won't overwrite existing install)
./aks-manager.ps1 install-argocd argocd-test

# Access via port-forward
kubectl port-forward svc/argocd-server -n default 8080:80

# Retrieve initial admin password
kubectl -n default get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | Out-String

# Bootstrap applications
./aks-manager.ps1 bootstrap
```

---

## 🔧 Cluster Configuration

| Component | Value |
|-----------|-------|
| Name | `dev` |
| Registry | `localhost:5000` |
| Servers | 1 node (8GB RAM) |
| Agents | 2 nodes (8GB RAM each) |
| Ports | 80:80, 443:443 (native Ingress) |
| Namespaces | argocd, monitoring, keda, external-secrets, cloudgames-dev |

---

## 📋 Project Structure
```
infrastructure/kubernetes/
├── manifests/           # ArgoCD Applications (app of apps, bootstrap)
├── scripts/             # Management scripts (k3d-manager + helpers)
├── base/                # Kustomize base (common, user, games, payments)
│   ├── common/          # Shared resources (ClusterSecretStore, Ingress)
│   ├── user/            # User API deployment + ExternalSecret
│   ├── games/           # Games API deployment + ExternalSecret
│   └── payments/        # Payments API deployment + ExternalSecret
└── overlays/            # Kustomize overlays (dev, prod)
```

---

## 🛠️ Troubleshooting

### Cluster Issues

| Problem | Solution |
|---------|----------|
| After reboot cluster doesn't work | `.\k3d-manager.ps1 start` |
| Port already in use | `.\k3d-manager.ps1 stop all` then `.\k3d-manager.ps1 list` |
| Pods not starting | `kubectl get pods -A` check events |
| Registry not accessible | `.\k3d-manager.ps1 cleanup` then recreate |
| Memory issues | Edit `create-all-from-zero.ps1` memory settings |
| Docker/network issues | `.\k3d-manager.ps1 check` |

### External Secrets Issues

```powershell
# Check ExternalSecret status
kubectl get externalsecrets -n cloudgames-dev

# View sync details
kubectl describe externalsecret user-api-secrets -n cloudgames-dev

# Check if secret was created
kubectl get secrets -n cloudgames-dev

# View operator logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

| Problem | Solution |
|---------|----------|
| ClusterSecretStore shows "Invalid" | Check Azure credentials: `kubectl describe clustersecretstore azure-keyvault` |
| CRDs not registered | Wait a few seconds and retry `.\k3d-manager.ps1 external-secrets` |
| API version mismatch | Update YAML files to `apiVersion: external-secrets.io/v1` |

---

## 💡 Tips

### PowerShell Alias (Recommended)
```powershell
# Add to PowerShell profile
notepad $PROFILE

# Add this line:
Set-Alias k3d "<repository-root>\infrastructure\kubernetes\scripts\k3d-manager.ps1"

# Reload
. $PROFILE

# Usage
k3d                       # Interactive menu
k3d status               # Cluster status
k3d create               # Create cluster
k3d port-forward grafana # Grafana port-forward
```

### View Service Logs
```powershell
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server      # ArgoCD
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana         # Grafana
kubectl logs -n cloudgames-dev -l app=user-api                       # Application
```

### Access Prometheus
```powershell
kubectl port-forward -n monitoring svc/kube-prom-stack-prometheus 9090:9090
# Access: http://localhost:9090
```

---

## 📝 Important Notes

1. **K3D Manager**: Use `.\k3d-manager.ps1` as the main entry point
2. **Native Ingress**: ArgoCD and APIs accessible without port-forward (via argocd.local and cloudgames.local)
3. **Hosts File**: REQUIRED - Run `.\k3d-manager.ps1 update-hosts` as Administrator (one-time)
4. **Port-forward**: Only needed for Grafana and Headlamp management UIs
5. **Idempotency**: Scripts can be run multiple times safely
6. **Passwords**: Configurable at the beginning of `create-all-from-zero.ps1`
7. **Persistence**: Grafana uses 5Gi PersistentVolume
8. **Registry**: Shared between cluster recreations
9. **Auto-sync**: ArgoCD monitors branch `feature/phase_04` for changes
10. **Secrets**: Never stored in Git - synced from Azure Key Vault via External Secrets Operator

---

## 🔗 Related Guides

- **Grafana Cloud Integration (AKS)**: For production AKS monitoring with Grafana Cloud, see [Grafana Agent Setup](../terraform/modules/grafana_agent/README.md)
