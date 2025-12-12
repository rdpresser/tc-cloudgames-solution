# 🚀 Local Kubernetes (K3D)

Local Kubernetes for development and testing, managed via the PowerShell **K3D Manager**.

## ⚡ Quick Start
```powershell
# Go to scripts folder
cd infrastructure\kubernetes\scripts

# Run the main manager (interactive menu)
.\k3d-manager.ps1
```

## 📋 Structure
```
infrastructure/kubernetes/
├── manifests/           # Argo CD Applications (app of apps, etc.)
├── scripts/             # Management scripts (manager + helpers)
├── base/                # Kustomize base (common, user, games, payments)
└── overlays/            # Kustomize overlays (dev, prod)
```

## 🏗️ Build & Push Images to k3d Registry
```powershell
# From repo root
cd C:\Projects\tc-cloudgames-solution

# Build images (adjust Dockerfile paths if needed)
docker build -t user-api:dev     -f services\users\src\Adapters\Inbound\TC.CloudGames.Users.Api\Dockerfile .
docker build -t games-api:dev    -f services\games\src\Adapters\Inbound\TC.CloudGames.Games.Api\Dockerfile .
docker build -t payments-api:dev -f services\payments\src\Adapters\Inbound\TC.CloudGames.Payments.Api\Dockerfile .

# Tag for k3d registry
docker tag user-api:dev     localhost:5000/user-api:dev
docker tag games-api:dev    localhost:5000/games-api:dev
docker tag payments-api:dev localhost:5000/payments-api:dev

# Push to registry
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

## 🎯 Deploy Applications via ArgoCD

After building and pushing images, deploy your applications using the **App of Apps** pattern:

```powershell
# Apply the bootstrap Application (creates all AppProjects and Applications)
kubectl apply -f manifests/application-bootstrap.yaml

# Verify ArgoCD Applications
kubectl get applications -n argocd

# Expected output:
# NAME        SYNC STATUS   HEALTH STATUS
# bootstrap   Synced        Healthy
# user-api    Synced        Healthy
# games-api   Synced        Healthy
# payments-api Synced       Healthy

# Check application pods
kubectl get pods -n cloudgames-dev
```

### ArgoCD CLI (Alternative)
```powershell
# Login to ArgoCD
argocd login localhost:8090 --username admin --password Argo@123 --insecure

# Create bootstrap application (app-of-apps pattern)
argocd app create bootstrap --file manifests/application-bootstrap.yaml

# Sync bootstrap (it deploys the unified cloudgames-dev Application)
argocd app sync bootstrap

# Watch sync status (single Application manages all 3 services)
argocd app list
argocd app get cloudgames-dev
```

### ArgoCD Web UI
1. Access: http://localhost:8090
2. Login: `admin` / `Argo@123`
3. Sync the **bootstrap** Application
4. The **cloudgames-dev** Application will be created and deploy all microservices
5. Auto-sync on Git push enabled (branch: `feature/phase_04`)

**Note**: The architecture uses a **unified Application** (`cloudgames-dev`) that manages all 3 microservices (user-api, games-api, payments-api) via the `overlays/dev` Kustomize path. This eliminates redundancy and conflicts from having separate Applications pointing to the same overlay.

---

## 🎯 Main Commands (via Manager)
```powershell
.\k3d-manager.ps1              # Interactive menu
.\k3d-manager.ps1 --help       # List all commands
.\k3d-manager.ps1 status       # Cluster status
.\k3d-manager.ps1 create       # Create cluster
.\k3d-manager.ps1 start        # Start after reboot
.\k3d-manager.ps1 port-forward all  # Port-forwards
```

## 🔗 Services
| Service   | URL                   | Credentials |
|-----------|-----------------------|-------------|
| **Argo CD**   | http://localhost:8090 | admin / Argo@123 |
| **Grafana**   | http://localhost:3000 | rdpresser / rdpresser@123 |
| **Headlamp**  | http://localhost:4466 | kubeconfig |

## 🔧 Cluster Configuration
| Component  | Value |
|------------|-------|
| Name       | `dev` |
| Registry   | `localhost:5000` |
| Nodes      | 1 server, 2 agents |
| Ports      | 80:80, 443:443 |
| Namespaces | argocd, monitoring, keda, users |

## 🚀 Common Workflows
```powershell
# First time
cd infrastructure\kubernetes\scripts
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all
# Access: http://localhost:8090 (Argo CD)

# After reboot
cd infrastructure\kubernetes\scripts
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all

# Status
.\k3d-manager.ps1 status
.\k3d-manager.ps1 list
kubectl get pods -A

# Clean and recreate
.\k3d-manager.ps1 cleanup
.\k3d-manager.ps1 create
```

## 🛠️ Quick Troubleshooting
- Cluster down after reboot: `./k3d-manager.ps1 start`
- Port-forward not connecting: `./k3d-manager.ps1 stop all` then `./k3d-manager.ps1 port-forward all`
- Docker/network issues: `./k3d-manager.ps1 check`
- Start over: `./k3d-manager.ps1 cleanup` then recreate

## 📚 More Docs
- **scripts/SCRIPTS-README.md** – Full script details
- **scripts/QUICK-REFERENCE.md** – Fast commands cheat sheet
- **scripts/TROUBLESHOOTING-NETWORK.md** – Network troubleshooting

## 🔗 Related Guides

- **Grafana Cloud Integration (AKS)**: For production AKS monitoring with Grafana Cloud, see [Grafana Agent Setup](../terraform/modules/grafana_agent/README.md).
  - [Why Azure Monitor + Grafana Agent](../terraform/modules/grafana_agent/README.md#executive-summary)
  - [Obtain Grafana Cloud Credentials](../terraform/modules/grafana_agent/README.md#credentials)
