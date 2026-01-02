# ⚡ Quick Start - AKS Production Setup

> **Fastest way to get a production AKS cluster running**

## 🎯 3-Step Setup

### Step 1: Create Infrastructure with Terraform

```powershell
cd infrastructure/terraform/foundation

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Wait 5-15 minutes...
```

### Step 2: Configure Kubernetes (One Command)

```powershell
cd infrastructure/kubernetes/scripts/prod

.\aks-manager.ps1 post-terraform-setup

# Done! ✅
```

### Step 3: Access Your Cluster

```powershell
# Get ArgoCD dashboard
.\aks-manager.ps1 get-argocd-url

# Check status
.\aks-manager.ps1 status
```

---

## ✅ What Gets Installed

✅ **AKS Cluster** - Kubernetes infrastructure  
✅ **ArgoCD** - GitOps deployments  
✅ **NGINX Ingress** - Single LoadBalancer for all services  
✅ **External Secrets** - Secrets sync from Key Vault  
✅ **Workload Identity** - Passwordless authentication  
✅ **Image Updater** - Auto-deploy new container images  
✅ **Applications** - All microservices deployed  

---

## 🐛 Troubleshooting

**Issue: LoadBalancer IP pending?**
```powershell
# Check status
.\aks-manager.ps1 status

# Reinstall NGINX
.\aks-manager.ps1 install-nginx
```

**Issue: ExternalSecrets not syncing?**
```powershell
# Check logs
kubectl logs -n external-secrets -f

# Reconfigure Workload Identity
.\aks-manager.ps1 setup-eso-wi
```

**Issue: Pods crashing?**
```powershell
# Check logs
kubectl logs -n cloudgames <pod-name> --previous

# Check secrets synced
kubectl get externalsecrets -n cloudgames
```

---

## 📚 Full Documentation

For complete details, see [README.md](README.md)

---

## 🚀 Next Steps

1. Access ArgoCD dashboard (URL from `get-argocd-url`)
2. Deploy your applications
3. Monitor via kubectl: `kubectl get pods -n cloudgames`
4. Check logs: `kubectl logs -n cloudgames <pod-name>`

---

**Need help?** Run `.\aks-manager.ps1 help` or `.\aks-manager.ps1` for interactive menu.
