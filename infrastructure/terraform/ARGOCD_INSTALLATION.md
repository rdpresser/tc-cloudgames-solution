# 🚀 ArgoCD Installation on AKS via Terraform

## 📋 Overview

ArgoCD é instalado automaticamente no cluster AKS via Terraform usando o **Helm Provider**. A instalação é feita durante o `terraform apply`, garantindo que o cluster já tenha ArgoCD pronto para GitOps.

---

## 🏗️ Arquitetura da Instalação

```
Terraform Apply
    │
    ├─► 1. Cria AKS Cluster (módulo aks_cluster)
    │
    ├─► 2. Configura Helm Provider
    │       └─► Conecta ao AKS via kubelogin
    │
    └─► 3. Instala ArgoCD (módulo argocd)
            ├─► Cria namespace "argocd"
            ├─► Deploy via Helm Chart
            ├─► Configura LoadBalancer
            └─► Define senha admin (bcrypt hash)
```

---

## 📁 Estrutura de Arquivos

### Módulo ArgoCD
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

## 🔐 Configuração da Senha

### Variável no Terraform Cloud

**Nome da variável:** `argocd_admin_password`  
**Tipo:** Terraform Variable  
**Sensitive:** ✅ Sim (marcar como sensitive)  
**Categoria:** Terraform variable  
**Descrição:** ArgoCD admin password (minimum 8 characters)

**Exemplo de valor:**
```
Argo@SecurePass123!
```

**Validação automática:**
- Mínimo 8 caracteres
- Stored como bcrypt hash no secret do ArgoCD

### Como Configurar no Terraform Cloud

1. Acesse o workspace `tc-cloudgames-dev`
2. Vá em **Variables**
3. Clique em **+ Add variable**
4. Configurações:
   - **Variable category:** Terraform variable
   - **Key:** `argocd_admin_password`
   - **Value:** `<sua-senha-segura>`
   - **Sensitive:** ✅ Marcado
   - **Description:** ArgoCD admin password
5. Clique em **Save variable**

---

## 🔧 Como Funciona

### 1. Bcrypt Password Hashing

```terraform
# modules/argocd/main.tf
resource "bcrypt_hash" "argocd_admin_password" {
  cleartext = var.admin_password
  cost      = 10
}
```

A senha é convertida em bcrypt hash (cost=10) antes de ser armazenada no ArgoCD.

### 2. Helm Chart Installation

```terraform
resource "helm_release" "argocd" {
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
