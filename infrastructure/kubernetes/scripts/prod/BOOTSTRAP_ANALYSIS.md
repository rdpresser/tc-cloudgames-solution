# 🔍 Análise Completa do Bootstrap AKS - Root Cause Analysis

**Data**: 28 de Janeiro de 2026  
**Problema**: 7 horas de troubleshooting para conseguir rodar aplicações no AKS  
**Root Cause**: Client-IDs hardcoded desatualizados nos deployments

---

## 📊 Resumo Executivo

### Problema Principal

Os **deployments** (`infrastructure/kubernetes/base/{games,payments,user}/deployment.yaml`) tinham `AZURE_CLIENT_ID` **hardcoded** com valores de um ambiente anterior/teste:

```yaml
# ❌ ANTES (valores errados hardcoded)
env:
  - name: AZURE_CLIENT_ID
    value: "fa8c944e-d16b-474e-91ac-82e56c0ce5e8" # ← NÃO EXISTE no Azure AD!
```

Quando a aplicação iniciava, tentava autenticar com `DefaultAzureCredential()` usando esse client-id inexistente, resultando em:

```
AADSTS700016: Application with identifier 'fa8c944e-d16b-474e-91ac-82e56c0ce5e8' was not found in the directory
```

### Impacto

- ✅ **Terraform criou corretamente** todas as Managed Identities
- ✅ **Terraform configurou corretamente** todos os RBAC (Service Bus, ACR, Application Insights)
- ✅ **ServiceAccounts** tinham as anotações corretas com client-ids válidos
- ❌ **Deployments** sobrescreviam com client-ids hardcoded inválidos
- ❌ **Webhook do Workload Identity ignorado** (env vars explícitas têm prioridade sobre injeção)

---

## 🏗️ Arquitetura Atual vs Ideal

### Estado Atual (Problemático)

```
┌─────────────────────────────────────────────────────────────────┐
│ 1️⃣ TERRAFORM (foundation/main.tf)                              │
│    ✅ Cria Managed Identities com client-ids dinâmicos         │
│    ✅ Configura RBAC (Service Bus, ACR, App Insights)          │
│    ✅ Cria Federated Identity Credentials (OIDC)               │
│    ✅ Exporta client-ids nos outputs                           │
└─────────────────────────────────────────────────────────────────┘
                            ⬇️
┌─────────────────────────────────────────────────────────────────┐
│ 2️⃣ KUBERNETES MANIFESTS (base/{service}/deployment.yaml)      │
│    ❌ HARDCODED client-ids antigos/inválidos                   │
│    ❌ Desconectado do Terraform                                │
│    ❌ Requer edição manual após cada terraform apply           │
└─────────────────────────────────────────────────────────────────┘
                            ⬇️
┌─────────────────────────────────────────────────────────────────┐
│ 3️⃣ ARGOCD (GitOps)                                            │
│    ✅ Sincroniza deployments do Git                            │
│    ❌ Sincroniza valores hardcoded errados                     │
│    ❌ Sem validação de client-ids                              │
└─────────────────────────────────────────────────────────────────┘
                            ⬇️
┌─────────────────────────────────────────────────────────────────┐
│ 4️⃣ PODS (Runtime)                                             │
│    ❌ Recebem AZURE_CLIENT_ID inválido via env vars           │
│    ❌ DefaultAzureCredential falha na autenticação             │
│    ❌ CrashLoopBackOff infinito                                │
└─────────────────────────────────────────────────────────────────┘
```

### Estado Ideal (Single-Shot)

```
┌─────────────────────────────────────────────────────────────────┐
│ 1️⃣ TERRAFORM (foundation/main.tf)                              │
│    ✅ Cria Managed Identities                                   │
│    ✅ Configura RBAC completo                                   │
│    ✅ Cria Federated Credentials                                │
│    ✅ Exporta client-ids, principal-ids, ACR name, etc.         │
│    ✅ CRIA AcrPull ROLE ASSIGNMENT para cada MI                 │
└─────────────────────────────────────────────────────────────────┘
                            ⬇️
┌─────────────────────────────────────────────────────────────────┐
│ 2️⃣ BOOTSTRAP SCRIPT (aks-manager.ps1 bootstrap-complete)       │
│    ✅ Conecta ao AKS                                            │
│    ✅ Instala ArgoCD via Helm (system pool tolerations)         │
│    ✅ Lê Terraform outputs dinamicamente                        │
│    ✅ Atualiza ServiceAccounts com client-ids corretos          │
│    ✅ Atualiza Deployments com client-ids corretos              │
│    ✅ Comita mudanças no Git                                    │
│    ✅ Aplica ArgoCD bootstrap (App-of-apps)                     │
│    ✅ Aguarda sincronização completa                            │
└─────────────────────────────────────────────────────────────────┘
                            ⬇️
┌─────────────────────────────────────────────────────────────────┐
│ 3️⃣ ARGOCD (GitOps)                                            │
│    ✅ Sincroniza manifests atualizados                          │
│    ✅ Client-ids sempre corretos (via bootstrap)                │
│    ✅ Health checks validam autenticação                        │
└─────────────────────────────────────────────────────────────────┘
                            ⬇️
┌─────────────────────────────────────────────────────────────────┐
│ 4️⃣ PODS (Runtime)                                             │
│    ✅ Recebem AZURE_CLIENT_ID válido                            │
│    ✅ DefaultAzureCredential autentica com sucesso              │
│    ✅ Conecta ao Service Bus, Key Vault, etc.                   │
│    ✅ Running/Healthy                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🐛 Problemas Identificados

### 1. **ACR Pull Permission - FALTA NO TERRAFORM** ⚠️

**Status**: ❌ **NÃO CONFIGURADO AUTOMATICAMENTE**

**O que existe**:

```terraform
# foundation/main.tf linha 179
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = local.enable_aks ? 1 : 0
  principal_id         = module.aks[0].kubelet_identity.object_id  # ← Kubelet apenas
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id
}
```

**O que falta**:

```terraform
# ❌ FALTANDO: AcrPull para cada Managed Identity das aplicações
resource "azurerm_role_assignment" "user_api_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.user_api.principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id
}

resource "azurerm_role_assignment" "games_api_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.games_api.principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id
}

resource "azurerm_role_assignment" "payments_api_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.payments_api.principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id
}
```

**Consequência**: Tivemos que executar manualmente:

```powershell
$acrId = az acr show --name tccloudgamesdevhvsbacr --query id -o tsv
$principalIds = @(
    "06c6e926-5ea0-4541-8dae-35b171938351",  # games-api
    "14669be1-4e12-469c-81f0-714e5d99ed9e",  # payments-api
    "152e27d4-7354-49fe-b0d7-0685b089322c"   # user-api
)
foreach ($principalId in $principalIds) {
    az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role "AcrPull" --scope $acrId
}
```

---

### 2. **Client-IDs Hardcoded nos Deployments** 🔥

**Arquivo**: `infrastructure/kubernetes/base/{games,payments,user}/deployment.yaml`

**Problema**:

```yaml
# deployment.yaml linha 50-57
env:
  - name: AZURE_TENANT_ID
    value: "084169c0-a779-43c3-970c-487a71a93f88"
  - name: AZURE_CLIENT_ID
    value: "fa8c944e-d16b-474e-91ac-82e56c0ce5e8" # ❌ HARDCODED ERRADO!
  - name: AZURE_FEDERATED_TOKEN_FILE
    value: "/var/run/secrets/workload-identity-token/token"
```

**Por que isso existe**:

- Azure Workload Identity **exige** que `AZURE_CLIENT_ID` esteja presente no pod
- `DefaultAzureCredential()` usa essa variável para WorkloadIdentityCredential
- **MAS**: Deveria vir do ServiceAccount annotation, NÃO hardcoded!

**Solução correta**:

```yaml
# ✅ OPÇÃO 1: Remover env vars completamente (deixar webhook injetar)
# Remover todo o bloco env: AZURE_* e deixar o webhook do Workload Identity injetar

# ✅ OPÇÃO 2: Usar valueFrom para ler annotation do ServiceAccount
env:
  - name: AZURE_CLIENT_ID
    valueFrom:
      fieldRef:
        fieldPath: metadata.annotations['azure.workload.identity/client-id']
  # ⬆️ Não funciona (annotations não são campos de runtime)

# ✅ OPÇÃO 3: Kustomize com patches dinâmicos
# Usar Kustomize replacements + ConfigMap gerado pelo Terraform
```

**Consequência**: Pods usavam client-id inexistente → falha de autenticação → CrashLoopBackOff

---

### 3. **ServiceAccounts Corretos Mas Ignorados**

**Status**: ✅ Configuração correta, ❌ Mas ignorada pelos deployments

**ServiceAccount** (`base/games/service-account.yaml`):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: games-api-sa
  annotations:
    azure.workload.identity/client-id: "b6d8b871-a12a-431a-8e1a-3d5c687614bd" # ✅ CORRETO
  labels:
    azure.workload.identity/use: "true" # ✅ CORRETO
```

**Deployment** referencia o ServiceAccount:

```yaml
spec:
  serviceAccountName: games-api-sa # ✅ CORRETO
```

**MAS**: Deployment tem env vars explícitas que **sobrescrevem** a injeção do webhook:

```yaml
env:
  - name: AZURE_CLIENT_ID
    value: "fa8c944e-d16b-474e-91ac-82e56c0ce5e8" # ❌ PRIORIDADE MAIOR QUE WEBHOOK!
```

**Ordem de precedência** (Kubernetes + Workload Identity):

1. **Env vars explícitas no Deployment** ← ❌ Usado (hardcoded errado)
2. Webhook mutation (se label `azure.workload.identity/use: "true"`)
3. ServiceAccount annotation

---

### 4. **Workflow Manual vs Automatizado**

**Fluxo atual (manual - 7 horas)**:

1. ✅ `terraform apply` → Cria infra
2. ❌ **PAUSA**: Copiar client-ids manualmente do output
3. ❌ **PAUSA**: Editar 3 arquivos `deployment.yaml` manualmente
4. ❌ **PAUSA**: Editar 3 arquivos `service-account.yaml` manualmente
5. ❌ **PAUSA**: `git commit` + `git push`
6. ❌ Rodar `aks-manager.ps1 install-argocd`
7. ❌ **PAUSA**: Aguardar ArgoCD instalar
8. ❌ Rodar `aks-manager.ps1 bootstrap-applications`
9. ❌ **PAUSA**: Pods em ImagePullBackOff (sem AcrPull)
10. ❌ Executar role assignment ACR manualmente
11. ❌ **PAUSA**: Pods em CrashLoopBackOff (client-id errado)
12. ❌ Debugar logs, encontrar erro de autenticação
13. ❌ Descobrir client-id hardcoded
14. ❌ Editar deployments novamente
15. ❌ `kubectl apply` + deletar pods
16. ✅ **FINALMENTE**: Pods Running

**Fluxo ideal (automatizado - single-shot)**:

1. ✅ `terraform apply` → Cria infra + outputs client-ids
2. ✅ `aks-manager.ps1 bootstrap-complete` →
   - Conecta ao AKS
   - Instala ArgoCD via Helm
   - Lê Terraform outputs
   - Atualiza ServiceAccounts + Deployments
   - Comita no Git
   - Aplica bootstrap ArgoCD
   - Aguarda health checks
3. ✅ **DONE**: Tudo running

---

## 🎯 Soluções Propostas

### Solução 1: **Terraform + Script Automático** (Recomendado para Produção)

**Vantagens**:

- ✅ Single-shot após `terraform apply`
- ✅ Sempre sincronizado com Terraform
- ✅ Git como source of truth
- ✅ ArgoCD mantém GitOps puro

**Arquitetura**:

```
Terraform (cria infra)
   ↓ outputs
Bootstrap Script (atualiza manifests)
   ↓ git commit
Git Repository (source of truth)
   ↓ ArgoCD sync
AKS (deployments atualizados)
```

**Implementação**:

**a) Adicionar AcrPull ao Terraform** (`foundation/main.tf`):

```terraform
# =============================================================================
# ACR Pull Permission for Application Managed Identities
# =============================================================================
resource "azurerm_role_assignment" "user_api_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.user_api.principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id

  depends_on = [
    azurerm_user_assigned_identity.user_api,
    module.acr
  ]
}

resource "azurerm_role_assignment" "games_api_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.games_api.principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id

  depends_on = [
    azurerm_user_assigned_identity.games_api,
    module.acr
  ]
}

resource "azurerm_role_assignment" "payments_api_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.payments_api.principal_id
  role_definition_name = "AcrPull"
  scope                = module.acr.acr_id

  depends_on = [
    azurerm_user_assigned_identity.payments_api,
    module.acr
  ]
}
```

**b) Adicionar outputs no Terraform** (`foundation/outputs.tf`):

```terraform
# Já existem outputs para client_id e principal_id ✅
# Adicionar output agregado para facilitar scripts:

output "workload_identities_summary" {
  description = "Summary of all Workload Identities for bootstrap scripts"
  value = {
    user_api = {
      client_id    = azurerm_user_assigned_identity.user_api.client_id
      principal_id = azurerm_user_assigned_identity.user_api.principal_id
      name         = azurerm_user_assigned_identity.user_api.name
    }
    games_api = {
      client_id    = azurerm_user_assigned_identity.games_api.client_id
      principal_id = azurerm_user_assigned_identity.games_api.principal_id
      name         = azurerm_user_assigned_identity.games_api.name
    }
    payments_api = {
      client_id    = azurerm_user_assigned_identity.payments_api.client_id
      principal_id = azurerm_user_assigned_identity.payments_api.principal_id
      name         = azurerm_user_assigned_identity.payments_api.name
    }
  }
  sensitive = false
}
```

**c) Melhorar script bootstrap** (`aks-manager.ps1`):

Já existe função `Update-ServiceAccountClientIds` (linha 415), **mas**:

- ❌ Atualiza apenas ServiceAccounts
- ❌ NÃO atualiza Deployments

**Adicionar**:

```powershell
function Update-DeploymentClientIds {
    param(
        [string]$TerraformPath = "C:\Projects\tc-cloudgames-solution\infrastructure\terraform\foundation"
    )

    Write-Step "Updating Deployment Client IDs from Terraform"

    # Get client IDs from Terraform
    Push-Location $TerraformPath
    try {
        $userApiClientId = (terraform output -raw user_api_client_id 2>$null)
        $gamesApiClientId = (terraform output -raw games_api_client_id 2>$null)
        $paymentsApiClientId = (terraform output -raw payments_api_client_id 2>$null)

        if (-not $userApiClientId -or -not $gamesApiClientId -or -not $paymentsApiClientId) {
            Write-Host "❌ Failed to retrieve client IDs from Terraform" -ForegroundColor $Colors.Error
            return $false
        }

        Write-Host "✅ Retrieved client IDs from Terraform" -ForegroundColor $Colors.Success
    }
    finally {
        Pop-Location
    }

    # Update deployment YAML files
    $k8sBasePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "base"
    $deployments = @(
        @{ Name = "user-api"; Path = Join-Path $k8sBasePath "user\deployment.yaml"; ClientId = $userApiClientId },
        @{ Name = "games-api"; Path = Join-Path $k8sBasePath "games\deployment.yaml"; ClientId = $gamesApiClientId },
        @{ Name = "payments-api"; Path = Join-Path $k8sBasePath "payments\deployment.yaml"; ClientId = $paymentsApiClientId }
    )

    foreach ($deploy in $deployments) {
        if (-not (Test-Path $deploy.Path)) {
            Write-Host "⚠️  File not found: $($deploy.Path)" -ForegroundColor $Colors.Warning
            continue
        }

        $content = Get-Content $deploy.Path -Raw

        # Update AZURE_CLIENT_ID env var value
        $pattern = '(- name: AZURE_CLIENT_ID\s+value:\s*")[^"]*(")'
        $replacement = "`${1}$($deploy.ClientId)`$2"

        if ($content -match $pattern) {
            $newContent = $content -replace $pattern, $replacement

            if ($content -eq $newContent) {
                Write-Host "✅ $($deploy.Name): Already up-to-date" -ForegroundColor $Colors.Success
            }
            else {
                Set-Content -Path $deploy.Path -Value $newContent -NoNewline
                Write-Host "✅ $($deploy.Name): Updated to $($deploy.ClientId)" -ForegroundColor $Colors.Success
            }
        }
        else {
            Write-Host "⚠️  $($deploy.Name): AZURE_CLIENT_ID pattern not found" -ForegroundColor $Colors.Warning
        }
    }

    return $true
}

function Update-AllManifestsFromTerraform {
    Write-Step "Syncing Kubernetes Manifests with Terraform State"

    # Update ServiceAccounts
    Update-ServiceAccountClientIds

    # Update Deployments
    $success = Update-DeploymentClientIds

    if (-not $success) {
        Write-Host "❌ Failed to update manifests" -ForegroundColor $Colors.Error
        return $false
    }

    # Git commit
    Write-Host ""
    Write-Host "📝 Committing changes to Git..." -ForegroundColor $Colors.Info

    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    Push-Location $repoRoot
    try {
        git add infrastructure/kubernetes/base/*/service-account.yaml
        git add infrastructure/kubernetes/base/*/deployment.yaml

        $status = git status --porcelain
        if ($status) {
            git commit -m "chore(k8s): Update Workload Identity client-ids from Terraform [automated]"
            Write-Host "✅ Changes committed" -ForegroundColor $Colors.Success
        }
        else {
            Write-Host "ℹ️  No changes to commit" -ForegroundColor $Colors.Info
        }
    }
    finally {
        Pop-Location
    }

    return $true
}
```

**d) Atualizar fluxo bootstrap-complete**:

```powershell
function Bootstrap-Complete {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
    Write-Host "║     SINGLE-SHOT AKS BOOTSTRAP (Post Terraform)           ║" -ForegroundColor $Colors.Title
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
    Write-Host ""

    # 1. Connect to AKS
    Write-Step "1/6: Connecting to AKS"
    Connect-AKS

    # 2. Sync manifests from Terraform
    Write-Step "2/6: Syncing Kubernetes manifests from Terraform state"
    $syncSuccess = Update-AllManifestsFromTerraform
    if (-not $syncSuccess) {
        Write-Host "❌ Manifest sync failed. Aborting." -ForegroundColor $Colors.Error
        return
    }

    # 3. Install ArgoCD
    Write-Step "3/6: Installing ArgoCD"
    Install-ArgoCD

    # 4. Bootstrap applications
    Write-Step "4/6: Bootstrapping GitOps applications"
    Bootstrap-Applications

    # 5. Setup External Secrets
    Write-Step "5/6: Setting up External Secrets Operator"
    Setup-ExternalSecrets

    # 6. Configure Image Updater
    Write-Step "6/6: Configuring ArgoCD Image Updater"
    Configure-ImageUpdater

    # 7. Wait for components
    Write-Step "Waiting for all components to be ready"
    Wait-ForComponents

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Success
    Write-Host "║   ✓ BOOTSTRAP COMPLETE - ALL SYSTEMS OPERATIONAL         ║" -ForegroundColor $Colors.Success
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Success

    Show-ClusterStatus
}
```

---

### Solução 2: **Remover Hardcoded + Confiar no Webhook** (Mais Simples, Mas Requer Validação)

**Vantagens**:

- ✅ Sem hardcoding
- ✅ Webhook injeta automaticamente
- ✅ ServiceAccount como única fonte

**Desvantagens**:

- ⚠️ Dependência total do webhook (single point of failure)
- ⚠️ Difícil debugar se webhook falhar
- ⚠️ Não funciona se webhook não estiver instalado

**Implementação**:

Remover todo o bloco `env: AZURE_*` dos deployments:

```yaml
# deployment.yaml - REMOVER ESTE BLOCO:
# env:
#   - name: AZURE_TENANT_ID
#     value: "084169c0-a779-43c3-970c-487a71a93f88"
#   - name: AZURE_CLIENT_ID
#     value: "fa8c944e-d16b-474e-91ac-82e56c0ce5e8"
#   - name: AZURE_FEDERATED_TOKEN_FILE
#     value: "/var/run/secrets/workload-identity-token/token"

# Manter apenas:
spec:
  serviceAccountName: games-api-sa # ✅ Webhook injeta baseado nisso
  containers:
    - name: games-api
      volumeMounts:
        - name: workload-identity-token
          mountPath: /var/run/secrets/workload-identity-token
          readOnly: true
```

**Validação necessária**:

- Verificar que webhook `azure-wi-webhook` está rodando
- Confirmar que label `azure.workload.identity/use: "true"` está no ServiceAccount
- Testar em ambiente dev antes de produção

---

### Solução 3: **Kustomize + ConfigMapGenerator** (GitOps Puro, Avançado)

**Vantagens**:

- ✅ GitOps puro (tudo no Git)
- ✅ Kustomize gerencia substituições
- ✅ Sem scripts externos
- ✅ ArgoCD nativo

**Desvantagens**:

- ⚠️ Requer Terraform local output → ConfigMap
- ⚠️ Mais complexo de configurar inicialmente
- ⚠️ Terraform ainda precisa rodar antes de aplicar Kustomize

**Implementação** (esboço):

**a) Terraform gera ConfigMap** (`foundation/main.tf`):

```terraform
resource "kubernetes_config_map" "workload_identities" {
  metadata {
    name      = "workload-identities"
    namespace = "cloudgames"
  }

  data = {
    user-api-client-id     = azurerm_user_assigned_identity.user_api.client_id
    games-api-client-id    = azurerm_user_assigned_identity.games_api.client_id
    payments-api-client-id = azurerm_user_assigned_identity.payments_api.client_id
  }

  depends_on = [module.aks]
}
```

**b) Kustomize replacements** (`overlays/prod/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

replacements:
  - source:
      kind: ConfigMap
      name: workload-identities
      fieldPath: data.games-api-client-id
    targets:
      - select:
          kind: Deployment
          name: games-api
        fieldPaths:
          - spec.template.spec.containers.[name=games-api].env.[name=AZURE_CLIENT_ID].value
```

**Problema**: Requer que Terraform **também gerencie** recursos Kubernetes, criando acoplamento.

---

## 🎯 Recomendação Final

### **Solução Híbrida (Melhor Custo-Benefício)**:

1. **Terraform**: Adicionar AcrPull role assignments (fix crítico)
2. **Deployments**: Remover hardcoded AZURE_CLIENT_ID (deixar webhook injetar)
3. **Bootstrap Script**: Validar que webhook está funcionando
4. **Fallback**: Se webhook falhar, script atualiza manualmente

**Implementação**:

**Fase 1 (Crítico - Fazer Agora)**:

- ✅ Adicionar `azurerm_role_assignment` AcrPull no Terraform
- ✅ Remover env vars AZURE\_\* dos deployments
- ✅ Confiar no webhook para injeção

**Fase 2 (Melhoria - Próxima Sprint)**:

- ✅ Criar função `Validate-WorkloadIdentityWebhook` no aks-manager.ps1
- ✅ Adicionar health checks pós-deployment
- ✅ Automatizar `terraform apply` → `bootstrap-complete` em CI/CD

**Fase 3 (Otimização - Futuro)**:

- ✅ Migrar para Kustomize replacements se equipe crescer
- ✅ Implementar ArgoCD ApplicationSet para multi-cluster

---

## 📊 Comparação de Soluções

| Critério               | Solução 1 (Script Auto) | Solução 2 (Webhook)        | Solução 3 (Kustomize)           |
| ---------------------- | ----------------------- | -------------------------- | ------------------------------- |
| **Complexidade Setup** | ⚠️ Média                | ✅ Baixa                   | ❌ Alta                         |
| **Manutenção**         | ✅ Fácil                | ✅ Fácil                   | ⚠️ Média                        |
| **GitOps Puro**        | ⚠️ Não (script externo) | ✅ Sim                     | ✅ Sim                          |
| **Single-Shot**        | ✅ Sim                  | ✅ Sim                     | ⚠️ Não (requer Terraform antes) |
| **Resiliência**        | ✅ Alta                 | ⚠️ Média (depende webhook) | ✅ Alta                         |
| **Time to Fix**        | 🕐 2 horas              | 🕐 30 min                  | 🕐 4 horas                      |
| **Recomendado**        | ✅ Produção             | ✅ **Início Rápido**       | ⚠️ Equipes grandes              |

---

## 🔧 Checklist de Implementação

### ✅ Terraform (`foundation/main.tf`)

- [ ] Adicionar `azurerm_role_assignment` AcrPull para user_api
- [ ] Adicionar `azurerm_role_assignment` AcrPull para games_api
- [ ] Adicionar `azurerm_role_assignment` AcrPull para payments_api
- [ ] Validar outputs `*_api_client_id` existem
- [ ] `terraform fmt` + `terraform validate`
- [ ] `terraform apply` e verificar roles no Azure Portal

### ✅ Kubernetes Manifests (`base/*/deployment.yaml`)

- [ ] **Remover** bloco `env: AZURE_CLIENT_ID` de games/deployment.yaml
- [ ] **Remover** bloco `env: AZURE_CLIENT_ID` de payments/deployment.yaml
- [ ] **Remover** bloco `env: AZURE_CLIENT_ID` de user/deployment.yaml
- [ ] Manter apenas `serviceAccountName: *-api-sa`
- [ ] Manter `volumeMounts: workload-identity-token`
- [ ] Git commit: `git commit -m "fix(k8s): Remove hardcoded AZURE_CLIENT_ID, rely on webhook injection"`

### ✅ ServiceAccounts (`base/*/service-account.yaml`)

- [ ] Validar annotation `azure.workload.identity/client-id` está presente
- [ ] Validar label `azure.workload.identity/use: "true"` está presente
- [ ] Executar `aks-manager.ps1 update-sa-client-ids` para sincronizar com Terraform

### ✅ Bootstrap Script (`aks-manager.ps1`)

- [ ] Adicionar função `Validate-WorkloadIdentityWebhook`
- [ ] Adicionar verificação de webhook em `Bootstrap-Complete`
- [ ] Adicionar timeout checks para pods ficarem Running
- [ ] Testar comando `.\aks-manager.ps1 bootstrap-complete` em cluster limpo

### ✅ Validação Final

- [ ] `terraform destroy` + `terraform apply` (teste full)
- [ ] `.\aks-manager.ps1 bootstrap-complete`
- [ ] Verificar pods: `kubectl get pods -n cloudgames -w`
- [ ] Verificar logs: `kubectl logs -n cloudgames -l app.kubernetes.io/name=games-api --tail=50`
- [ ] Verificar ArgoCD: `kubectl get applications -n argocd`
- [ ] Testar aplicação: `curl http://cloudgames.local/games/health`

---

## 📚 Referências

### Documentação Consultada

- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/docs/)
- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize Replacements](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/replacements/)

### Scripts de Referência

- `infrastructure/kubernetes/scripts/scripts_ref/bootstrap.ps1` - K3D bootstrap com Helm
- `infrastructure/kubernetes/scripts/prod/aks-manager.ps1` - AKS manager atual
- `infrastructure/kubernetes/scripts/prod/configure-image-updater.ps1` - Atualiza annotations

### Terraform Modules

- `infrastructure/terraform/modules/external_secrets/main.tf` - Exemplo correto de Workload Identity
- `infrastructure/terraform/foundation/main.tf` - Managed Identities + RBAC

---

## 💡 Lições Aprendidas

1. **Nunca hardcode client-ids** - Sempre usar Terraform outputs ou ServiceAccount annotations
2. **Workload Identity tem ordem de precedência** - Env vars explícitas > webhook > annotations
3. **AcrPull é obrigatório para Managed Identities** - Não apenas para Kubelet
4. **Bootstrap deve ser idempotente** - Pode rodar múltiplas vezes sem quebrar
5. **GitOps requer disciplina** - Manifests no Git devem sempre refletir Terraform state
6. **Validação é crítica** - Health checks evitam 7 horas de debug
7. **Scripts > Manual** - Automatizar reduz erro humano drasticamente

---

**Próximos Passos**: Implementar Solução 2 (Webhook) + adicionar AcrPull no Terraform
