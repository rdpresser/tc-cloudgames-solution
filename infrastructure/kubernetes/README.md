# 🚀 K3D Cluster Management

> Complete local Kubernetes development environment with **native Ingress support** - no port-forward needed!

## ⚡ Quick Start

```powershell
# Interactive menu
cd infrastructure\kubernetes\scripts
.\k3d-manager.ps1

# Direct commands
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all
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
# Adds argocd.local and cloudgames.local to hosts file
.\k3d-manager.ps1 update-hosts
```

Or manually add to `C:\Windows\System32\drivers\etc\hosts`:
```
127.0.0.1 argocd.local
127.0.0.1 cloudgames.local
```

Test after deploying apps:
```powershell
Invoke-WebRequest http://argocd.local
Invoke-WebRequest http://cloudgames.local/user/health
Invoke-WebRequest http://cloudgames.local/games/health
Invoke-WebRequest http://cloudgames.local/payments/health
```

---

## 🎯 Recommended Flow

### Complete Setup (First Time)
```powershell
# 1. Create cluster (ArgoCD, KEDA, Prometheus, Grafana)
.\k3d-manager.ps1 create

# 2. Update hosts file (REQUIRED - run as Administrator)
.\k3d-manager.ps1 update-hosts

# 3. Configure External Secrets (Azure Key Vault integration)
.\k3d-manager.ps1 external-secrets

# 4. Bootstrap ArgoCD applications
.\k3d-manager.ps1 bootstrap

# 5. (Optional) Start port-forward for Grafana only
.\k3d-manager.ps1 port-forward grafana

# 6. (Optional) Start Headlamp UI
.\k3d-manager.ps1 headlamp
```

### After Reboot
```powershell
.\k3d-manager.ps1 start
# Port-forward only needed for Grafana
.\k3d-manager.ps1 port-forward grafana
```

### Status & Monitoring
```powershell
.\k3d-manager.ps1 status
.\k3d-manager.ps1 list
.\k3d-manager.ps1 secrets
```

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
| `reset-argocd-app.ps1` | Reset ArgoCD application (clear cache and recreate) |

### Utilities
| Script | Description |
|--------|-------------|
| `check-docker-network.ps1` | Diagnose Docker/network issues |
| `update-hosts-file.ps1` | Add argocd.local and cloudgames.local to hosts file (requires Admin) |
| `start-headlamp-docker.ps1` | Start Headlamp UI container |

---

## 🔗 Service Access

### Native Ingress (NO port-forward needed!)
| Service  | URL                   | Credentials | Setup |
|----------|-----------------------|-------------|-------|
| ArgoCD   | http://argocd.local | admin / Argo@123 | `.\k3d-manager.ps1 update-hosts` |
| User API | http://cloudgames.local/user | - | Requires hosts file update |
| Games API | http://cloudgames.local/games | - | Requires hosts file update |
| Payments API | http://cloudgames.local/payments | - | Requires hosts file update |

### Management Services (require port-forward)
| Service  | URL                   | Credentials | Command |
|----------|-----------------------|-------------|---------|
| Grafana  | http://localhost:3000 | rdpresser / rdpresser@123 | `.\k3d-manager.ps1 port-forward grafana` |
| Headlamp | http://localhost:4466 | kubeconfig | `.\k3d-manager.ps1 headlamp` |

### Application APIs (native - NO port-forward needed!)
| Service  | URL                                  | Notes |
|----------|--------------------------------------|-------|
| User API | http://cloudgames.local/user        | Add to hosts: 127.0.0.1 cloudgames.local |
| Games API | http://cloudgames.local/games      | Uses native port mapping (80:80@loadbalancer) |
| Payments API | http://cloudgames.local/payments | Works like a real cluster! |

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
# Apply bootstrap (creates all Applications)
kubectl apply -f manifests/application-bootstrap.yaml

# Verify
kubectl get applications -n argocd
kubectl get pods -n cloudgames-dev
```

**ArgoCD Web UI**: http://localhost:8090 (admin / Argo@123)

---

## 🔧 Cluster Configuration

| Component | Value |
|-----------|-------|
| Name       | `dev` |
| Registry   | `localhost:5000` |
| Servers    | 1 node (8GB RAM) |
| Agents     | 2 nodes (8GB RAM each) |
| Ports      | 80:80, 443:443 |
| Namespaces | argocd, monitoring, keda, cloudgames-dev |

---

## 📋 Structure
```
infrastructure/kubernetes/
├── manifests/           # Argo CD Applications (app of apps, etc.)
├── scripts/             # Management scripts (manager + helpers)
├── base/                # Kustomize base (common, user, games, payments)
└── overlays/            # Kustomize overlays (dev, prod)
```

---

## 🛠️ Troubleshooting

### After reboot cluster doesn't work
```powershell
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all
```

### Port-forward issues
```powershell
.\k3d-manager.ps1 stop all
.\k3d-manager.ps1 list
.\k3d-manager.ps1 port-forward all
```

### Docker/network issues
```powershell
.\k3d-manager.ps1 check
```

### Full reset
```powershell
.\k3d-manager.ps1 cleanup
.\k3d-manager.ps1 create
```

### Common Issues

| Problem | Solution |
|---------|----------|
| Port already in use | `netstat -ano \| findstr "8090"` then `.\k3d-manager.ps1 stop all` |
| Pods not starting | `kubectl get pods -A` check events, restart deployment |
| Registry not accessible | `.\k3d-manager.ps1 cleanup` then recreate |
| Memory issues | Edit `create-all-from-zero.ps1` memory settings |

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
k3d                    # Interactive menu
k3d status            # Cluster status
k3d create            # Create cluster
k3d port-forward all  # Port-forwards
```

### View Service Logs
```powershell
# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Application
kubectl logs -n cloudgames-dev -l app=user-api
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
3. **Hosts File**: REQUIRED - Run `.\k3d-manager.ps1 update-hosts` as Administrator
4. **Idempotency**: Scripts can be run multiple times safely
5. **Passwords**: Configurable at the beginning of `create-all-from-zero.ps1`
6. **Persistence**: Grafana uses 5Gi PersistentVolume
7. **Registry**: Shared between cluster recreations
8. **Port-forwards**: Only needed for Grafana and Headlamp management UIs
9. **Auto-sync**: ArgoCD monitors branch `feature/phase_04` for changes

---

## 🔗 Related Guides

- **Grafana Cloud Integration (AKS)**: For production AKS monitoring with Grafana Cloud, see [Grafana Agent Setup](../terraform/modules/grafana_agent/README.md)
  - [Why Azure Monitor + Grafana Agent](../terraform/modules/grafana_agent/README.md#executive-summary)
  - [Obtain Grafana Cloud Credentials](../terraform/modules/grafana_agent/README.md#credentials)
