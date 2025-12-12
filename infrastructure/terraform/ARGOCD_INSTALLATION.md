# 🚀 ArgoCD Installation on AKS via Terraform

## 📋 Overview

ArgoCD is automatically installed on the AKS cluster via Terraform using the **Helm Provider**. Installation happens during `terraform apply`, ensuring the cluster has ArgoCD ready for GitOps.

---

## 🏗️ Installation Architecture

```
Terraform Apply
    │
    ├─► 1. Create AKS Cluster (aks_cluster module)
    │
    ├─► 2. Configure Helm Provider
    │       └─► Connect to AKS via kubelogin
    │
    └─► 3. Install ArgoCD (argocd module)
            ├─► Create "argocd" namespace
            ├─► Deploy via Helm Chart
            ├─► Configure LoadBalancer
            └─► Set admin password (bcrypt hash)
```

---

## 📁 File Structure

### ArgoCD Module
```
modules/argocd/
├─ main.tf          # Helm release + namespace + bcrypt password
├─ variables.tf     # admin_password (sensitive)
└─ outputs.tf       # server_url, server_ip, admin_username, etc.
```

### Foundation
```
foundation/
├─ providers.tf     # Helm + Kubernetes + Bcrypt providers
├─ main.tf          # module "argocd" declaration
├─ variables.tf     # argocd_admin_password (sensitive)
└─ outputs.tf       # argocd_info, argocd_server_url
```

---

## 🔐 Password Configuration

### Terraform Cloud Variable

**Variable name:** `argocd_admin_password`  
**Type:** Terraform Variable  
**Sensitive:** ✅ Yes (mark as sensitive)  
**Category:** Terraform variable  
**Description:** ArgoCD admin password (minimum 8 characters)

**Example value:**
```
Argo@SecurePass123!
```

**Automatic validation:**
- Minimum 8 characters
- Stored as bcrypt hash in ArgoCD secret

### How to Configure in Terraform Cloud

1. Access workspace `tc-cloudgames-dev`
2. Go to **Variables**
3. Click **+ Add variable**
4. Configuration:
   - **Variable category:** Terraform variable
   - **Key:** `argocd_admin_password`
   - **Value:** `<your-secure-password>`
   - **Sensitive:** ✅ Checked
   - **Description:** ArgoCD admin password
5. Click **Save variable**

---

## 🔧 How It Works

### 1. Bcrypt Password Hashing

```terraform
# modules/argocd/main.tf
resource "bcrypt_hash" "argocd_admin_password" {
  cleartext = var.admin_password
  cost      = 10
}
```

The password is converted to a bcrypt hash (cost=10) before being stored in ArgoCD.

### 2. Helm Chart Installation

```terraform
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  # LoadBalancer for external access
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  # Insecure mode (no TLS) for easier access
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Admin password (bcrypt hash)
  set_sensitive {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt_hash.argocd_admin_password.id
  }
}
```

### 3. LoadBalancer Service

ArgoCD server is exposed via **Azure Load Balancer** with automatic public IP.

---

## 📤 Available Outputs

After `terraform apply`, the following outputs will be available:

```hcl
# ArgoCD full URL
output "argocd_server_url"
# Example: http://20.123.45.67

# Detailed information
output "argocd_info" {
  namespace            = "argocd"
  server_url           = "http://20.123.45.67"
  server_ip            = "20.123.45.67"
  admin_username       = "admin"
  helm_release_name    = "argocd"
  helm_release_version = "5.51.0"
}
```

---

## 🎯 Accessing ArgoCD

### Option 1: Via LoadBalancer (Recommended)

```bash
# 1. Get URL from terraform output
terraform output argocd_server_url
# Output: http://20.123.45.67

# 2. Open in browser
http://20.123.45.67

# 3. Login
Username: admin
Password: <terraform-cloud-value>
```

### Option 2: Via Port-Forward (Local)

```bash
# 1. Connect to cluster
az aks get-credentials \
  --resource-group <rg-name> \
  --name <aks-name>

# 2. Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 3. Open in browser
http://localhost:8080

# 4. Login
Username: admin
Password: <terraform-cloud-value>
```

### Option 3: Via ArgoCD CLI

```bash
# 1. Install ArgoCD CLI
choco install argocd  # Windows
brew install argocd   # macOS
# Linux: https://argo-cd.readthedocs.io/en/stable/cli_installation/

# 2. Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 3. Login via CLI
argocd login localhost:8080 \
  --insecure \
  --username admin \
  --password <terraform-cloud-value>

# 4. List applications
argocd app list
```

---

## 🔄 Comparison: K3d (Dev) vs AKS (Prod)

### PowerShell Script (K3d - Local Dev)
```powershell
# create-all-from-zero.ps1
# 1. Install ArgoCD via Helm manually
helm upgrade --install argocd argo/argo-cd -n argocd

# 2. Retrieve initial password
$argocdInitialPassword = kubectl -n argocd get secret ...

# 3. Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 4. Change password via CLI
argocd login localhost:8080 --username admin --password $argocdInitialPassword
argocd account update-password --new-password "Argo@123"
```

### Terraform (AKS - Production)
```terraform
# foundation/main.tf
module "argocd" {
  source = "../modules/argocd"
  admin_password = var.argocd_admin_password  # From Terraform Cloud
}

# ✅ Password already set on deployment (bcrypt hash)
# ✅ LoadBalancer with automatic public IP
# ✅ No need to change password manually
# ✅ Password managed via Terraform Cloud (sensitive)
```

---

## 🛠️ Required Providers

### Automatic Installation via Terraform

```terraform
# foundation/providers.tf
terraform {
  required_providers {
    azurerm    = "~> 4.0"     # Azure resources
    helm       = "~> 2.12"    # ArgoCD installation
    kubernetes = "~> 2.25"    # Namespace creation
    bcrypt     = "~> 0.1"     # Password hashing
  }
}
```

### Authentication via kubelogin

```terraform
provider "helm" {
  kubernetes {
    exec {
      command = "kubelogin"
      args = [
        "get-token",
        "--login", "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"
      ]
    }
  }
}
```

**Prerequisite:** `kubelogin` must be installed in the Terraform execution environment (Terraform Cloud Agent or local).

---

## 📊 Resource Limits

Default resource configurations:

### ArgoCD Server
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### ArgoCD Controller
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
```

### ArgoCD Repo Server
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

---

## 🐛 Troubleshooting

### Error: "Module not found: argocd"
```bash
# Run terraform init
cd infrastructure/terraform/foundation
terraform init
```

### Error: "kubelogin command not found"
```bash
# Install kubelogin
az aks install-cli  # Installs kubectl and kubelogin

# Verify installation
kubelogin --version
```

### Error: "LoadBalancer pending forever"
```bash
# Check service status
kubectl -n argocd get svc argocd-server

# Check events
kubectl -n argocd describe svc argocd-server

# Check load balancer in Azure
az network lb list -o table
```

### Error: "Cannot login to ArgoCD"
```bash
# Verify password is correct
# Password must match Terraform Cloud configuration

# Manually reset password (if needed)
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "<new-bcrypt-hash>"}}'
```

---

## 📈 Costs

### ArgoCD (Azure)
- **LoadBalancer:** ~$20/month (public IP + rules)
- **Pods (resources):** Included in AKS node costs
- **Additional Total:** ~$20/month

---

## ✅ Post-Deploy Validation

```bash
# 1. Check ArgoCD pods
kubectl -n argocd get pods

# Expected:
# argocd-server-xxxxx              1/1   Running
# argocd-repo-server-xxxxx         1/1   Running
# argocd-application-controller-0  1/1   Running
# argocd-redis-xxxxx               1/1   Running
# argocd-dex-server-xxxxx          1/1   Running

# 2. Check LoadBalancer service
kubectl -n argocd get svc argocd-server

# Expected:
# NAME            TYPE           EXTERNAL-IP
# argocd-server   LoadBalancer   20.123.45.67

# 3. Test access
curl http://<EXTERNAL-IP>

# Expected: ArgoCD login page HTML
```

---

## 🎯 Next Steps

After ArgoCD installation:

1. **Connect Git repository** in ArgoCD
2. **Create Application CRDs** for users-api, games-api, payments-api
3. **Deploy via GitOps:** Push manifests → automatic ArgoCD sync
4. **Configure auto-sync** and self-heal for automatic deployments

---

## 📚 References

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [Helm Chart Documentation](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Kubelogin (Azure AD Auth)](https://azure.github.io/kubelogin/)

---

## 🔑 Variable Summary

**Terraform Cloud variable name:**
```
argocd_admin_password
```

**Type:** Terraform Variable  
**Sensitive:** Yes  
**Validation:** Minimum 8 characters  
**Usage:** Password for `admin` user in ArgoCD  
**Storage:** Bcrypt hash (cost=10) in ArgoCD secret

**Example configuration:**
```
argocd_admin_password = "Argo@SecurePass123!"
```

---

**Status:** ArgoCD automatically installed via Terraform ✅  
**Deploy:** Together with `terraform apply` of foundation  
**Access:** LoadBalancer public IP + Terraform Cloud password  
**GitOps Ready:** Ready for application deployment 🚀
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  # LoadBalancer para acesso externo
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  # Insecure mode (sem TLS) para facilitar acesso
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Senha admin (bcrypt hash)
  set_sensitive {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt_hash.argocd_admin_password.id
  }
}
```

### 3. LoadBalancer Service

ArgoCD server é exposto via **Azure Load Balancer** com IP público automático.

---

## 📤 Outputs Disponíveis

Após `terraform apply`, os seguintes outputs estarão disponíveis:

```hcl
# URL completa do ArgoCD
output "argocd_server_url"
# Exemplo: http://20.123.45.67

# Informações detalhadas
output "argocd_info" {
  namespace            = "argocd"
  server_url           = "http://20.123.45.67"
  server_ip            = "20.123.45.67"
  admin_username       = "admin"
  helm_release_name    = "argocd"
  helm_release_version = "5.51.0"
}
```

---

## 🎯 Acesso ao ArgoCD

### Opção 1: Via LoadBalancer (Recomendado)

```bash
# 1. Obter URL do terraform output
terraform output argocd_server_url
# Output: http://20.123.45.67

# 2. Abrir no navegador
http://20.123.45.67

# 3. Login
Username: admin
Password: <valor-do-terraform-cloud>
```

### Opção 2: Via Port-Forward (Local)

```bash
# 1. Conectar ao cluster
az aks get-credentials \
  --resource-group <rg-name> \
  --name <aks-name>

# 2. Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 3. Abrir no navegador
http://localhost:8080

# 4. Login
Username: admin
Password: <valor-do-terraform-cloud>
```

### Opção 3: Via ArgoCD CLI

```bash
# 1. Instalar ArgoCD CLI
choco install argocd  # Windows
brew install argocd   # macOS
# Linux: https://argo-cd.readthedocs.io/en/stable/cli_installation/

# 2. Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 3. Login via CLI
argocd login localhost:8080 \
  --insecure \
  --username admin \
  --password <valor-do-terraform-cloud>

# 4. Listar aplicações
argocd app list
```

---

## 🔄 Comparação: K3d (Dev) vs AKS (Prod)

### Script PowerShell (K3d - Local Dev)
```powershell
# create-all-from-zero.ps1
# 1. Instala ArgoCD via Helm manualmente
helm upgrade --install argocd argo/argo-cd -n argocd

# 2. Recupera senha inicial
$argocdInitialPassword = kubectl -n argocd get secret ...

# 3. Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 4. Altera senha via CLI
argocd login localhost:8080 --username admin --password $argocdInitialPassword
argocd account update-password --new-password "Argo@123"
```

### Terraform (AKS - Produção)
```terraform
# foundation/main.tf
module "argocd" {
  source = "../modules/argocd"
  admin_password = var.argocd_admin_password  # From Terraform Cloud
}

# ✅ Senha já definida no deploy (bcrypt hash)
# ✅ LoadBalancer com IP público automático
# ✅ Não precisa alterar senha manualmente
# ✅ Senha gerenciada via Terraform Cloud (sensitive)
```

---

## 🛠️ Providers Necessários

### Instalação Automática via Terraform

```terraform
# foundation/providers.tf
terraform {
  required_providers {
    azurerm    = "~> 4.0"     # Azure resources
    helm       = "~> 2.12"    # ArgoCD installation
    kubernetes = "~> 2.25"    # Namespace creation
    bcrypt     = "~> 0.1"     # Password hashing
  }
}
```

### Autenticação via kubelogin

```terraform
provider "helm" {
  kubernetes {
    exec {
      command = "kubelogin"
      args = [
        "get-token",
        "--login", "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"
      ]
    }
  }
}
```

**Pré-requisito:** `kubelogin` deve estar instalado no ambiente de execução do Terraform (Terraform Cloud Agent ou local).

---

## 📊 Resource Limits

Configurações padrão de recursos:

### ArgoCD Server
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### ArgoCD Controller
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
```

### ArgoCD Repo Server
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

---

## 🐛 Troubleshooting

### Erro: "Module not found: argocd"
```bash
# Executar terraform init
cd infrastructure/terraform/foundation
terraform init
```

### Erro: "kubelogin command not found"
```bash
# Instalar kubelogin
az aks install-cli  # Instala kubectl e kubelogin

# Verificar instalação
kubelogin --version
```

### Erro: "LoadBalancer pending forever"
```bash
# Verificar status do service
kubectl -n argocd get svc argocd-server

# Verificar eventos
kubectl -n argocd describe svc argocd-server

# Verificar load balancer no Azure
az network lb list -o table
```

### Erro: "Cannot login to ArgoCD"
```bash
# Verificar se senha está correta
# A senha deve ser a mesma configurada no Terraform Cloud

# Resetar senha manualmente (se necessário)
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "<novo-bcrypt-hash>"}}'
```

---

## 📈 Custos

### ArgoCD (Azure)
- **LoadBalancer:** ~$20/mês (IP público + regras)
- **Pods (recursos):** Incluído no custo dos nodes AKS
- **Total Adicional:** ~$20/mês

---

## ✅ Validação Pós-Deploy

```bash
# 1. Verificar pods do ArgoCD
kubectl -n argocd get pods

# Esperado:
# argocd-server-xxxxx              1/1   Running
# argocd-repo-server-xxxxx         1/1   Running
# argocd-application-controller-0  1/1   Running
# argocd-redis-xxxxx               1/1   Running
# argocd-dex-server-xxxxx          1/1   Running

# 2. Verificar service LoadBalancer
kubectl -n argocd get svc argocd-server

# Esperado:
# NAME            TYPE           EXTERNAL-IP
# argocd-server   LoadBalancer   20.123.45.67

# 3. Testar acesso
curl http://<EXTERNAL-IP>

# Esperado: HTML da página de login do ArgoCD
```

---

## 🎯 Próximos Passos

Após instalação do ArgoCD:

1. **Conectar repositório Git** no ArgoCD
2. **Criar Application CRDs** para users-api, games-api, payments-api
3. **Deploy via GitOps:** Push manifests → ArgoCD sync automático
4. **Configurar auto-sync** e self-heal para deployments automáticos

---

## 📚 Referências

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [Helm Chart Documentation](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Kubelogin (Azure AD Auth)](https://azure.github.io/kubelogin/)

---

## 🔑 Resumo da Variável

**Nome da variável no Terraform Cloud:**
```
argocd_admin_password
```

**Tipo:** Terraform Variable  
**Sensitive:** Sim  
**Validação:** Mínimo 8 caracteres  
**Uso:** Senha do usuário `admin` no ArgoCD  
**Storage:** Bcrypt hash (cost=10) no secret do ArgoCD

**Exemplo de configuração:**
```
argocd_admin_password = "Argo@SecurePass123!"
```

---

**Status:** ArgoCD instalado automaticamente via Terraform ✅  
**Deploy:** Junto com `terraform apply` do foundation  
**Acesso:** LoadBalancer IP público + senha do Terraform Cloud  
**GitOps Ready:** Pronto para deploy de aplicações 🚀
