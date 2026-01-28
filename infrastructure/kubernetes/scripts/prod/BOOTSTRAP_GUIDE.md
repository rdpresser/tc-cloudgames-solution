# 🚀 AKS Bootstrap Guide - Single-Shot Setup

## TL;DR - Quick Start (Recommended)

```powershell
# After terraform apply completes:
cd infrastructure/kubernetes/scripts/prod
.\aks-manager.ps1 bootstrap-complete
```

**That's it!** This single command executes the entire setup automatically.

---

## 📋 What `bootstrap-complete` Does

The `bootstrap-complete` command executes the following steps automatically:

1. **Connect to AKS cluster** - Fetches credentials and sets kubectl context
2. **Update ServiceAccount client IDs** - Syncs Workload Identity client IDs from Terraform outputs
3. **Install ArgoCD** - Deploys ArgoCD with system pool tolerations (auto-applied)
4. **Bootstrap applications** - Applies all ArgoCD Application manifests (GitOps)
5. **Setup External Secrets** - Configures ESO with Azure Workload Identity
6. **Configure Image Updater** - Sets up ArgoCD Image Updater for ACR
7. **Validate webhooks** - Ensures all webhooks are healthy
8. **Wait for components** - Confirms all pods are running

### 🔄 Idempotency Guarantee

This setup is **fully idempotent**:

- ✅ Safe to run multiple times
- ✅ Skips already installed components
- ✅ Only adds missing pieces
- ✅ Never breaks existing configurations

---

## 🎯 Architecture Decisions

### System Pool Tolerations

**Q: Why is `system-pod-tolerations.yaml` applied inside the ArgoCD install script instead of Kustomize?**

**A:** Because of installation order:

1. ArgoCD must be installed **BEFORE** Kustomize applications
2. `system-pod-tolerations.yaml` patches ArgoCD deployments (which don't exist yet during Kustomize apply)
3. Solution: Apply tolerations automatically inside `install-argocd-aks.ps1` after ArgoCD installation

**Current workflow:**

```
install-argocd-aks.ps1 runs:
  1. Install ArgoCD (default node pool)
  2. Apply system-pod-tolerations.yaml (adds tolerations + nodeSelector)
  3. Restart ArgoCD pods (kubectl rollout restart)
  4. Pods migrate to system pool
```

This ensures ArgoCD always runs on the system node pool, isolated from application workload during k6 load tests.

---

## 🛠️ Alternative: Manual Step-by-Step

If you need granular control, you can execute individual steps:

```powershell
cd infrastructure/kubernetes/scripts/prod

# 1. Connect to cluster
.\aks-manager.ps1 connect

# 2. Update ServiceAccount client IDs
.\aks-manager.ps1 update-sa-client-ids

# 3. Install ArgoCD (with system pool tolerations)
.\aks-manager.ps1 install-argocd

# 4. Bootstrap applications
.\aks-manager.ps1 bootstrap

# 5. Setup ESO with Workload Identity
.\aks-manager.ps1 setup-eso-wi

# 6. Configure Image Updater
.\aks-manager.ps1 configure-image-updater
```

---

## 📊 Interactive Menu

For a guided experience, run without arguments:

```powershell
.\aks-manager.ps1
```

**Menu highlights:**

- **[B] Bootstrap Complete** - Single-shot setup (recommended)
- **[1] Connect** - Get AKS credentials
- **[2] Status** - Show cluster status with component health
- **[13] Post-Terraform Setup** - Alternative single-shot (same as bootstrap-complete)

---

## 🔍 Verification

After bootstrap completes, verify the setup:

```powershell
# Check cluster status
.\aks-manager.ps1 status

# Get ArgoCD URL and credentials
.\aks-manager.ps1 get-argocd-url

# View ArgoCD applications
kubectl get applications -n argocd

# Check component health
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
kubectl get pods -n external-secrets
kubectl get pods -n argocd-image-updater
```

---

## 🏗️ Node Pool Architecture

The cluster uses separated node pools for stability during load tests:

### Node Pools Configuration

| Pool       | Size          | Count             | Purpose                         | Taint                                |
| ---------- | ------------- | ----------------- | ------------------------------- | ------------------------------------ |
| `default`  | Standard_B2ms | 1 (fixed)         | System components (kube-system) | None                                 |
| `system`   | Standard_B2ms | 2 (fixed)         | ArgoCD, critical add-ons        | `CriticalAddonsOnly=true:NoSchedule` |
| `workload` | Standard_B2ms | 2-6 (autoscaling) | Application APIs                | None                                 |

### Pod Scheduling

**ArgoCD components** (after tolerations applied):

- `nodeSelector: { workload-type: system }`
- `toleration: CriticalAddonsOnly=true:NoSchedule`
- **Schedules on:** `system` pool

**Application APIs** (users, games, payments):

- `nodeSelector: { workload-type: application }`
- **Schedules on:** `workload` pool

**Benefits:**

- ArgoCD remains stable during k6 load tests
- Applications can autoscale independently
- System components isolated from workload noise

---

## 📝 Troubleshooting

### ArgoCD not accessible

```powershell
# Get LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Reset password
.\aks-manager.ps1 reset-argocd-password
```

### Webhook errors

```powershell
# Fix all webhooks (NGINX, ESO, Workload Identity)
.\aks-manager.ps1 fix-webhooks
```

### Pods stuck in Pending

```powershell
# Check node pool resources
kubectl get nodes
kubectl describe node <node-name>

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

### ArgoCD sync issues

```powershell
# Force sync all applications
.\aks-manager.ps1 fix-argocd-sync
```

---

## 🔗 Related Documentation

- [aks-manager.ps1](./aks-manager.ps1) - Main orchestrator script
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Detailed architecture decisions
- [README.md](./README.md) - Component installation details
- [QUICK_START.md](./QUICK_START.md) - Quick reference guide

---

## 🎓 Lessons Learned from scripts_ref

This implementation was inspired by the k3d local cluster setup (`scripts_ref/`), applying the following principles:

1. **Single-Shot Bootstrap** - One command to rule them all (`bootstrap.ps1` → `bootstrap-complete`)
2. **Idempotency** - Safe to run multiple times (`Invoke-Retry`, `Test-ComponentInstalled`)
3. **Interactive Menu** - User-friendly CLI (`manager.ps1` → improved menu with status)
4. **Modular Scripts** - Each script does one thing well
5. **Automatic Orchestration** - Manager calls individual scripts in correct order

**Key differences for AKS:**

- ArgoCD installed via kubectl (not Helm) to match YAML manifests
- Workload Identity instead of secrets
- Node pool separation for load test stability
- Terraform-managed infrastructure

---

## ✅ Success Criteria

After `bootstrap-complete` finishes, you should have:

- ✅ ArgoCD UI accessible via LoadBalancer IP
- ✅ All applications synced in ArgoCD
- ✅ ArgoCD pods running on `system` pool
- ✅ Application pods running on `workload` pool
- ✅ External Secrets fetching from Key Vault
- ✅ Image Updater monitoring ACR for new tags
- ✅ NGINX Ingress routing traffic

**Next step:** Build and push images

```powershell
.\aks-manager.ps1 build-push all
```

---

**Created:** 2026-01-28  
**Author:** TC Cloud Games - Infrastructure Team  
**Version:** 1.0 (Single-Shot Bootstrap)
