# 🚀 K3D Cluster Management Scripts

> Use **k3d-manager.ps1** for all common tasks (interactive menu + CLI).

## ⚡ Quick Start
```powershell
# Interactive menu
.\k3d-manager.ps1

# Help
.\k3d-manager.ps1 --help

# Direct commands
.\k3d-manager.ps1 status
.\k3d-manager.ps1 create
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all
.\k3d-manager.ps1 headlamp
```

## 🎯 Recommended Flow

### Complete Setup (First Time)
```powershell
# 1. Create cluster (ArgoCD, KEDA, Prometheus, Grafana)
.\k3d-manager.ps1 create

# 2. Configure External Secrets (Azure Key Vault integration)
.\k3d-manager.ps1 external-secrets

# 3. Bootstrap ArgoCD applications
.\k3d-manager.ps1 bootstrap

# 4. Start port-forwards
.\k3d-manager.ps1 port-forward all

# 5. (Optional) Start Headlamp UI
.\k3d-manager.ps1 headlamp
```

### After Reboot
```powershell
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all
```

### Status & Monitoring
```powershell
.\k3d-manager.ps1 status
.\k3d-manager.ps1 list
.\k3d-manager.ps1 secrets
```

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
| `port-forward.ps1` | Start port-forwards (ArgoCD 8090, Grafana 3000) |
| `stop-port-forward.ps1` | Stop specific or all port-forwards |
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

### Utilities
| Script | Description |
|--------|-------------|
| `check-docker-network.ps1` | Diagnose Docker/network issues |
| `start-headlamp-docker.ps1` | Start Headlamp UI container |

## 🔗 Services
| Service  | URL                   | Credentials |
|----------|-----------------------|-------------|
| Argo CD  | http://localhost:8090 | admin / Argo@123 |
| Grafana  | http://localhost:3000 | rdpresser / rdpresser@123 |
| Headlamp | http://localhost:4466 | kubeconfig |

## 🏗️ Build & Push Images (k3d registry) {#build-push-images}
```powershell
cd C:\Projects\tc-cloudgames-solution

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

## 🛠️ Troubleshooting
- Port-forward issues: `./k3d-manager.ps1 stop all` then `./k3d-manager.ps1 port-forward all`
- Cluster stopped after reboot: `./k3d-manager.ps1 start`
- Docker/network issues: `./k3d-manager.ps1 check`
- Full reset: `./k3d-manager.ps1 cleanup` then recreate

## 💡 Tips
- Add alias in PowerShell profile: `Set-Alias k3d "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\k3d-manager.ps1"`
- Use `k3d` to open menu, `k3d status`, `k3d create`, `k3d port-forward all`.

## 🔗 Related Guides

- **Grafana Cloud Integration (AKS)**: For production AKS monitoring, see [Grafana Agent Setup](../../terraform/modules/grafana_agent/README.md).
  - [Why Azure Monitor + Grafana Agent](../../terraform/modules/grafana_agent/README.md#executive-summary)
  - [Obtain Grafana Cloud Credentials](../../terraform/modules/grafana_agent/README.md#credentials)

.\stop-port-forward.ps1
.\stop-port-forward.ps1 all

# Stop only ArgoCD
.\stop-port-forward.ps1 argocd

# Stop only Grafana
.\stop-port-forward.ps1 grafana
```

---

### 4️⃣ **`list-port-forward.ps1`** 📋

**Function**: Lists running port-forwards with details.

**What it does:**
- Shows all active kubectl port-forward processes
- Displays PID, service, port and uptime
- Useful for monitoring and troubleshooting

**Usage:**
```powershell
.\list-port-forward.ps1
```

**Example output:**
```
=== Active Port-Forwards ===

🔗 Active Port-Forward:
   Service: argocd-server
   Port:    http://localhost:8090
   PID:     12345
   Uptime:  00:15:32

🔗 Active Port-Forward:
   Service: kube-prom-stack-grafana
   Port:    http://localhost:3000
   PID:     12346
   Uptime:  00:15:30
```

---

### 4.1️⃣ **`check-docker-network.ps1`** 🔍

**Function**: Diagnoses Docker network issues before creating cluster.

**What it does:**
- Checks if Docker is running
- Tests container connectivity
- Validates `host.docker.internal` resolution
- Identifies backend mode (WSL2/Hyper-V)
- Checks available resources (CPU/RAM)
- Checks required ports (80, 443, 8090, 3000)

**Usage:**
```powershell
.\check-docker-network.ps1
# or via manager
.\k3d-manager.ps1 check
```

**When to use:**
- ✅ Before creating the cluster for the first time
- ✅ After connectivity issues
- ✅ When kubectl doesn't connect to the cluster
- ✅ After Docker Desktop changes

---

### 4.2️⃣ **`start-headlamp-docker.ps1`** 🎨

**Function**: Starts Headlamp Kubernetes UI in Docker container.

**What it does:**
- Generates compatible temporary kubeconfig
- Removes previous container if exists
- Starts Headlamp on port 4466
- Configures access to k3d cluster

**Usage:**
```powershell
.\start-headlamp-docker.ps1
# or via manager
.\k3d-manager.ps1 headlamp
```

**Access:**
- **URL**: http://localhost:4466
- Graphical interface to manage the k3d cluster

**Features:**
- ✅ Modern Kubernetes UI
- ✅ Resource visualization
- ✅ Logs and metrics
- ✅ Simplified management

---

### 4.3️⃣ **`list-secrets.ps1`** 🔑

**Function**: Lists and searches Kubernetes secrets synced from Azure Key Vault.

**What it does:**
- Lists all secrets in application namespaces
- Filters by secret name or key
- Shows ExternalSecrets sync status
- Optionally decodes secret values (with masking for sensitive data)

**Usage:**
```powershell
# List all secrets in cloudgames-dev
.\list-secrets.ps1
.\k3d-manager.ps1 secrets

# Filter by secret name
.\list-secrets.ps1 -SecretName "user*"

# Search for specific key
.\list-secrets.ps1 -Key "db-password"

# Show decoded values (careful!)
.\list-secrets.ps1 -SecretName "user-api-secrets" -Decode

# Search all namespaces
.\list-secrets.ps1 -Namespace all
```

**Example Output:**
```
📦 Namespace: cloudgames-dev
------------------------------------------------------------
   🔐 user-api-secrets (Type: Opaque, Keys: 27)
      • db-host
      • db-port
      • db-password
      ...

📊 ExternalSecrets Sync Status:
   ✅ user-api-secrets - Status: SecretSynced
   ✅ games-api-secrets - Status: SecretSynced
   ✅ payments-api-secrets - Status: SecretSynced
```

---

### 4.4️⃣ **`bootstrap-argocd-apps.ps1`** 🚀

**Function**: Bootstraps ArgoCD applications for GitOps deployment.

**What it does:**
- Verifies prerequisites (cluster, ArgoCD, External Secrets)
- Applies bootstrap manifest to ArgoCD
- Optionally waits for applications to sync
- Shows deployment status

**Usage:**
```powershell
# Bootstrap dev environment (default)
.\bootstrap-argocd-apps.ps1
.\k3d-manager.ps1 bootstrap

# Bootstrap specific environment
.\bootstrap-argocd-apps.ps1 -Environment dev
.\bootstrap-argocd-apps.ps1 -Environment prod

# Dry run (show what would be applied)
.\bootstrap-argocd-apps.ps1 -DryRun

# Wait for sync completion
.\bootstrap-argocd-apps.ps1 -Wait
```

**Prerequisites:**
- ✅ Cluster running (`.\k3d-manager.ps1 create`)
- ✅ External Secrets configured (`.\k3d-manager.ps1 external-secrets`)

---

### 5️⃣ **`cleanup-all.ps1`** 🗑️

**Function**: Completely removes the cluster and resources.

**What it does:**
- Stops all port-forwards
- Removes Headlamp container
- Deletes k3d cluster
- Removes local registry (optional)

**Usage:**
```powershell
.\cleanup-all.ps1
# or via manager
.\k3d-manager.ps1 cleanup
```

**When to use:**
- ✅ To start from scratch
- ✅ Free system resources
- ✅ Resolve persistent issues
- ⚠️ WARNING: Removes all cluster data

---

## 🎯 Typical Workflow

### 🆕 First time:
```powershell
# Option 1: Via manager (recommended)
.\k3d-manager.ps1
# Choose option 1 (Create cluster)
# Then option 3 (Port-forward all)

# Option 2: Via command line
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all

# Option 3: Direct scripts
.\create-all-from-zero.ps1
.\port-forward.ps1 all
```

### 🔄 After restarting the computer:
```powershell
# Via manager (recommended)
.\k3d-manager.ps1
# Choose option 2 (Start cluster)
# Then option 3 (Port-forward all)

# Via command line
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all

# Direct scripts
.\start-cluster.ps1
.\port-forward.ps1 all
```

### 📊 During development:
```powershell
# Check status
.\k3d-manager.ps1 status

# List port-forwards
.\k3d-manager.ps1 list

# Start Headlamp UI
.\k3d-manager.ps1 headlamp

# Stop port-forwards
.\k3d-manager.ps1 stop all
```

### 🔧 Troubleshooting:
```powershell
# Check Docker
.\k3d-manager.ps1 check

# View full status
.\k3d-manager.ps1 status

# Recreate cluster from scratch
.\k3d-manager.ps1 cleanup
.\k3d-manager.ps1 create
```

---

## 🔐 Default Credentials

### ArgoCD
- **URL**: http://localhost:8090 (HTTP)
- **User**: `admin`
- **Password**: `Argo@123`

### Grafana
- **URL**: http://localhost:3000
- **Admin**: `admin` / `Grafana@123`
- **User**: `rdpresser` / `rdpresser@123` (Admin role)

### Headlamp
- **URL**: http://localhost:4466
- Uses local kubeconfig automatically

---

## ⚙️ Cluster Configuration

The `create-all-from-zero.ps1` script creates a cluster with:

| Component | Configuration |
|-----------|---------------|
| **Cluster Name** | `dev` |
| **Registry** | `localhost:5000` |
| **Servers** | 1 node (8GB RAM) |
| **Agents** | 2 nodes (8GB RAM each) |
| **Ports** | 80:80, 443:443 |
| **Namespaces** | argocd, monitoring, keda, users |

---

## 🛠️ Troubleshooting

### ⚠️ After restarting the computer the cluster doesn't work
**Problem**: Port-forwards fail, kubectl doesn't connect, services inaccessible.

**Cause**: k3d containers stop when Docker Desktop is restarted.

**Solution**:
```powershell
# 1. Start Docker Desktop and wait
# 2. Run:
.\start-cluster.ps1

# 3. Then port-forward:
.\port-forward.ps1 all
```

### ⚠️ Port-forward creates duplicate processes
**Problem**: Multiple kubectl processes on port 8090/3000.

**Cause**: Chocolatey shim creating duplicate processes.

**Solution**: The script now detects and uses the real kubectl executable automatically.

```powershell
# If it still occurs:
.\k3d-manager.ps1 stop all
.\k3d-manager.ps1 list
.\k3d-manager.ps1 port-forward all
```

### Registry already exists
The script detects and reuses existing registry automatically.

### Cluster won't delete
```powershell
# Force manual deletion
k3d cluster delete dev

# Then run the script
.\create-all-from-zero.ps1
```

### Port-forward won't start
```powershell
# Check if port is already in use
netstat -ano | findstr "8090"
netstat -ano | findstr "3000"

# Stop existing processes
.\stop-port-forward.ps1 all

# Try again
.\port-forward.ps1 all
```

### Port-forward doesn't connect or loses connection
```powershell
# Check if pods are running
kubectl get pods -n argocd
kubectl get pods -n monitoring

# Restart port-forwards
.\stop-port-forward.ps1 all
.\port-forward.ps1 all
```

### Memory issues
Edit the variables at the beginning of `create-all-from-zero.ps1`:
```powershell
$memoryPerNode = "8g"  # Adjust as needed
$agentMemory = "8g"    # Adjust as needed
```

---

## 📝 Important Notes

1. **K3D Manager**: Use `.\k3d-manager.ps1` as the main entry point
2. **Interactive Menu**: Run without parameters for visual menu
3. **Command Line**: All commands support direct execution
4. **Idempotency**: Scripts can be run multiple times safely
5. **Passwords**: Configurable at the beginning of `create-all-from-zero.ps1`
6. **Persistence**: Grafana uses 5Gi PersistentVolume
7. **Registry**: Shared between cluster recreations
8. **Port-forwards**: Processes run in background (WindowStyle Hidden)
9. **Headlamp**: Alternative graphical interface to manage the cluster
10. **Status**: Use `.\k3d-manager.ps1 status` for quick overview

---

## 🗑️ Removed/Deprecated Scripts

| Script | Status | Reason | Alternative |
|--------|--------|--------|-------------|
| `restore-after-delete.ps1` | ❌ REMOVED | Identical to create-all-from-zero.ps1 | Use `create-all-from-zero.ps1` |
| `PORT-FORWARD-README.md` | ❌ REMOVED | Documentation consolidated | See sections above in this README |

---

## 💡 Tips

### Using K3D Manager (Recommended)

```powershell
# Create permanent alias in PowerShell Profile
notepad $PROFILE

# Add to file:
Set-Alias k3d "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\k3d-manager.ps1"

# Save and reload:
. $PROFILE

# Simplified usage:
k3d                    # Interactive menu
k3d status            # Cluster status
k3d create            # Create cluster
k3d start             # Start cluster
k3d port-forward all  # Port-forwards
k3d headlamp          # Start Headlamp
```

### Create alias in PowerShell Profile (Individual Scripts)

```powershell
# Add to $PROFILE
Set-Alias k3d-reset "C:\...\create-all-from-zero.ps1"
Set-Alias pf "C:\...\port-forward.ps1"
Set-Alias pf-stop "C:\...\stop-port-forward.ps1"
Set-Alias pf-list "C:\...\list-port-forward.ps1"

# Usage
k3d-reset
pf all
pf-list
pf-stop all
```

### View service logs

```powershell
# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Access Prometheus

```powershell
kubectl port-forward -n monitoring svc/kube-prom-stack-prometheus 9090:9090
# Access: http://localhost:9090
```
