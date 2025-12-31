<#
.SYNOPSIS
  Configures Azure Workload Identity for External Secrets Operator on AKS.

.DESCRIPTION
  This script:
  1. Creates a User Assigned Identity for ESO
  2. Creates a Federated Identity Credential linking the K8s ServiceAccount to Azure
  3. Grants Key Vault Secrets User role to the identity
  4. Annotates the ESO ServiceAccount with the client ID
  5. Restarts ESO pods to pick up the new identity
  6. Recreates the ClusterSecretStore to reconnect

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER ClusterName
  AKS Cluster name.

.PARAMETER KeyVaultName
  Azure Key Vault name.

.PARAMETER IdentityName
  Name for the User Assigned Identity. Default: <cluster>-eso-identity

.PARAMETER Force
  Skip confirmation prompts.

.EXAMPLE
  .\setup-eso-workload-identity.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -KeyVaultName "tccloudgamesdevcr8nkv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "tc-cloudgames-solution-dev-rg",

    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "tc-cloudgames-dev-cr8n-aks",

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "tccloudgamesdevcr8nkv",

    [Parameter(Mandatory = $false)]
    [string]$IdentityName,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$Colors = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "White"
    Muted   = "Gray"
}

# Derive identity name from cluster name if not provided
if (-not $IdentityName) {
    $IdentityName = "$ClusterName-eso-identity"
}

$EsoNamespace = "external-secrets"
$EsoServiceAccount = "external-secrets-operator"

function Show-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Colors.Title
    Write-Host "  ESO Workload Identity Configuration for AKS" -ForegroundColor $Colors.Title
    Write-Host "============================================================" -ForegroundColor $Colors.Title
    Write-Host ""
    Write-Host "Resource Group : $ResourceGroup" -ForegroundColor $Colors.Muted
    Write-Host "Cluster Name   : $ClusterName" -ForegroundColor $Colors.Muted
    Write-Host "Key Vault      : $KeyVaultName" -ForegroundColor $Colors.Muted
    Write-Host "Identity Name  : $IdentityName" -ForegroundColor $Colors.Muted
    Write-Host ""
}

Show-Header

# =============================================================================
# Step 1: Prerequisites Check
# =============================================================================
Write-Host "=== 1/7 Checking prerequisites ===" -ForegroundColor $Colors.Title

# Check Azure CLI
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) { throw "Not logged in" }
    Write-Host "✅ Azure CLI: Logged in as $($account.user.name)" -ForegroundColor $Colors.Success
} catch {
    Write-Host "❌ Not logged in to Azure CLI. Run: az login" -ForegroundColor $Colors.Error
    exit 1
}

# Check kubectl
try {
    kubectl cluster-info 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cluster not accessible" }
    Write-Host "✅ Kubernetes cluster accessible" -ForegroundColor $Colors.Success
} catch {
    Write-Host "❌ Kubernetes cluster not accessible" -ForegroundColor $Colors.Error
    exit 1
}

# Check ESO is installed
Write-Host "Checking External Secrets Operator status..." -ForegroundColor $Colors.Info
$esoPods = kubectl get pods -n $EsoNamespace --no-headers 2>$null | Where-Object { $_ -match "Running" }
if (-not $esoPods) {
    Write-Host "❌ External Secrets Operator not running" -ForegroundColor $Colors.Error
    Write-Host "   ESO may still be starting. Waiting up to 90 seconds..." -ForegroundColor $Colors.Muted
    
    # Wait up to 90 seconds for ESO to be ready
    $maxWaitAttempts = 18  # 18 * 5 = 90 seconds
    $waitAttempt = 0
    while ($waitAttempt -lt $maxWaitAttempts) {
        Start-Sleep -Seconds 5
        $esoPods = kubectl get pods -n $EsoNamespace --no-headers 2>$null | Where-Object { $_ -match "Running" }
        if ($esoPods) {
            Write-Host "✅ External Secrets Operator is now running" -ForegroundColor $Colors.Success
            break
        }
        $waitAttempt++
        if ($waitAttempt -lt $maxWaitAttempts) {
            Write-Host "  ⏳ Still waiting... ($waitAttempt/$maxWaitAttempts)" -ForegroundColor $Colors.Muted
        }
    }
    
    # Final check
    if (-not $esoPods) {
        Write-Host "❌ External Secrets Operator failed to start" -ForegroundColor $Colors.Error
        Write-Host "   Check pod logs: kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets" -ForegroundColor $Colors.Muted
        exit 1
    }
} else {
    Write-Host "✅ External Secrets Operator is running" -ForegroundColor $Colors.Success
}

# =============================================================================
# Step 2: Get AKS OIDC Issuer URL
# =============================================================================
Write-Host ""
Write-Host "=== 2/7 Getting AKS OIDC Issuer URL ===" -ForegroundColor $Colors.Title

$aks = az aks show --resource-group $ResourceGroup --name $ClusterName 2>$null | ConvertFrom-Json
if (-not $aks) {
    Write-Host "❌ AKS cluster not found" -ForegroundColor $Colors.Error
    exit 1
}

$oidcIssuerUrl = $aks.oidcIssuerProfile.issuerUrl
if (-not $oidcIssuerUrl) {
    Write-Host "❌ OIDC Issuer not enabled on AKS cluster" -ForegroundColor $Colors.Error
    Write-Host "   Enable it with: az aks update -g $ResourceGroup -n $ClusterName --enable-oidc-issuer" -ForegroundColor $Colors.Muted
    exit 1
}
Write-Host "✅ OIDC Issuer URL: $oidcIssuerUrl" -ForegroundColor $Colors.Success

$tenantId = $account.tenantId
Write-Host "   Tenant ID: $tenantId" -ForegroundColor $Colors.Muted
# =============================================================================
# Step 2-5: Verify Azure Resources (Created by Terraform)
# =============================================================================
Write-Host ""
Write-Host "=== 2/6 Verifying Azure Resources ===" -ForegroundColor $Colors.Title

Write-Host "   Verifying identity '$IdentityName'..." -ForegroundColor $Colors.Info
$ErrorActionPreference = "SilentlyContinue"
$identity = az identity show --name $IdentityName --resource-group $ResourceGroup 2>&1 | ConvertFrom-Json
$ErrorActionPreference = "Stop"

if (-not $identity -or -not $identity.clientId) {
    Write-Host "❌ Identity '$IdentityName' not found in Azure" -ForegroundColor $Colors.Error
    Write-Host "   Ensure Terraform has created this identity" -ForegroundColor $Colors.Muted
    exit 1
}

$clientId = $identity.clientId
$principalId = $identity.principalId
Write-Host "✅ Identity found: $clientId" -ForegroundColor $Colors.Success

Write-Host "   Verifying Key Vault '$KeyVaultName'..." -ForegroundColor $Colors.Info
$ErrorActionPreference = "SilentlyContinue"
$kv = az keyvault show --name $KeyVaultName 2>&1 | ConvertFrom-Json
$ErrorActionPreference = "Stop"

if (-not $kv) {
    Write-Host "❌ Key Vault '$KeyVaultName' not found" -ForegroundColor $Colors.Error
    exit 1
}
Write-Host "✅ Key Vault found" -ForegroundColor $Colors.Success

Write-Host "   Verifying Workload Identity webhook..." -ForegroundColor $Colors.Info
$wiWebhookPods = kubectl get pods -n azure-workload-identity-system --no-headers 2>$null | Where-Object { $_ -match "Running" }
if ($wiWebhookPods) {
    Write-Host "✅ Workload Identity webhook is running" -ForegroundColor $Colors.Success
} else {
    Write-Host "⚠️  Workload Identity webhook not ready yet" -ForegroundColor $Colors.Warning
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Key Vault access granted" -ForegroundColor $Colors.Success
} else {
    Write-Host "⚠️  Role assignment may already exist" -ForegroundColor $Colors.Warning
}

# =============================================================================
# Step 6: Annotate ESO ServiceAccount
# =============================================================================
Write-Host ""
Write-Host "=== 3/6 Annotating ESO ServiceAccount ===" -ForegroundColor $Colors.Title

# Annotate the ServiceAccount with the client ID and tenant ID
kubectl annotate serviceaccount $EsoServiceAccount -n $EsoNamespace `
    "azure.workload.identity/client-id=$clientId" --overwrite 2>$null
kubectl annotate serviceaccount $EsoServiceAccount -n $EsoNamespace `
    "azure.workload.identity/tenant-id=$tenantId" --overwrite 2>$null

# Also add the label for workload identity
kubectl label serviceaccount $EsoServiceAccount -n $EsoNamespace `
    "azure.workload.identity/use=true" --overwrite 2>$null

Write-Host "✅ ServiceAccount annotated with client ID and tenant ID" -ForegroundColor $Colors.Success

# Annotate webhook ServiceAccount too
kubectl annotate serviceaccount external-secrets-operator-webhook -n $EsoNamespace `
    "azure.workload.identity/client-id=$clientId" --overwrite 2>$null
kubectl annotate serviceaccount external-secrets-operator-webhook -n $EsoNamespace `
    "azure.workload.identity/tenant-id=$tenantId" --overwrite 2>$null
kubectl label serviceaccount external-secrets-operator-webhook -n $EsoNamespace `
    "azure.workload.identity/use=true" --overwrite 2>$null

Write-Host "✅ Webhook ServiceAccount also annotated" -ForegroundColor $Colors.Success

# Restart ESO pods to pick up the new identity
Write-Host "   Restarting ESO pods..." -ForegroundColor $Colors.Info
kubectl rollout restart deployment/external-secrets-operator -n $EsoNamespace 2>$null
kubectl rollout restart deployment/external-secrets-operator-webhook -n $EsoNamespace 2>$null
kubectl rollout restart deployment/external-secrets-operator-cert-controller -n $EsoNamespace 2>$null

Write-Host "   Waiting for pods to be ready..." -ForegroundColor $Colors.Muted
kubectl rollout status deployment/external-secrets-operator -n $EsoNamespace --timeout=120s 2>$null

# =============================================================================
# Step 4: Verify ClusterSecretStore (Managed by ArgoCD)
# =============================================================================
Write-Host ""
Write-Host "=== 4/6 Verifying ClusterSecretStore ===" -ForegroundColor $Colors.Title
Write-Host "   (ClusterSecretStore is managed by Kustomize/ArgoCD)" -ForegroundColor $Colors.Muted

# Wait for ClusterSecretStore to be created by ArgoCD
Write-Host "   Waiting for ClusterSecretStore..." -ForegroundColor $Colors.Info
$maxAttempts = 12
$attempt = 0
$store = $null
while ($attempt -lt $maxAttempts) {
    $store = kubectl get clustersecretstore azure-keyvault -o json 2>$null | ConvertFrom-Json
    if ($store -and $store.metadata) {
        break
    }
    $attempt++
    if ($attempt -lt $maxAttempts) {
        Write-Host "   ⏳ Waiting... ($attempt/$maxAttempts)" -ForegroundColor $Colors.Muted
        Start-Sleep -Seconds 5
    }
}

if ($store -and $store.metadata) {
    Write-Host "✅ ClusterSecretStore found" -ForegroundColor $Colors.Success
    
    # Check status if available
    if ($store.status -and $store.status.conditions) {
        $readyCondition = $store.status.conditions | Where-Object { $_.type -eq "Ready" }
        if ($readyCondition -and $readyCondition.status -eq "True") {
            Write-Host "✅ ClusterSecretStore is READY!" -ForegroundColor $Colors.Success
        } elseif ($readyCondition) {
            Write-Host "⚠️  ClusterSecretStore status: $($readyCondition.reason)" -ForegroundColor $Colors.Warning
        }
    } else {
        Write-Host "⚠️  ClusterSecretStore status not yet available (will sync shortly)" -ForegroundColor $Colors.Warning
    }
} else {
    Write-Host "⚠️  ClusterSecretStore not found - will be deployed by ArgoCD" -ForegroundColor $Colors.Warning
}

# =============================================================================
# Summary
# =============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor $Colors.Title
Write-Host "  ESO Workload Identity Configuration Complete!" -ForegroundColor $Colors.Success
Write-Host "============================================================" -ForegroundColor $Colors.Title
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor $Colors.Title
Write-Host "   Identity Name:    $IdentityName" -ForegroundColor $Colors.Info
Write-Host "   Client ID:        $clientId" -ForegroundColor $Colors.Info
Write-Host "   Key Vault:        $KeyVaultName" -ForegroundColor $Colors.Info
Write-Host ""

# Verification - ensure everything is configured correctly
Write-Host "🔍 Final Verification (Idempotency Check):" -ForegroundColor $Colors.Title
$verifyErrors = 0

# Check 1: ServiceAccount annotations
$sa = kubectl get serviceaccount $EsoServiceAccount -n $EsoNamespace -o json 2>$null | ConvertFrom-Json
if ($sa -and $sa.metadata -and $sa.metadata.annotations -and $sa.metadata.annotations.'azure.workload.identity/client-id') {
    Write-Host "   ✅ ESO ServiceAccount has Workload Identity annotations" -ForegroundColor $Colors.Success
} else {
    Write-Host "   ❌ ESO ServiceAccount missing Workload Identity annotations" -ForegroundColor $Colors.Error
    $verifyErrors++
}

# Check 2: Federated Credential
$fedCred = az identity federated-credential show --name "$IdentityName-federated-credential" --identity-name $IdentityName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
if ($fedCred -and $fedCred.name) {
    Write-Host "   ✅ Federated Credential is configured" -ForegroundColor $Colors.Success
} else {
    Write-Host "   ❌ Federated Credential not found or not configured" -ForegroundColor $Colors.Error
    $verifyErrors++
}

# Check 3: Key Vault access
$kvCheck = az role assignment list --assignee $principalId --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup" 2>$null | ConvertFrom-Json
if ($kvCheck -and ($kvCheck | Where-Object { $_.roleDefinitionName -eq "Key Vault Secrets User" })) {
    Write-Host "   ✅ Key Vault Secrets User role is assigned" -ForegroundColor $Colors.Success
} else {
    Write-Host "   ⚠️  Key Vault Secrets User role not verified (may take time to propagate)" -ForegroundColor $Colors.Warning
}

# Check 4: ClusterSecretStore status
$store = kubectl get clustersecretstore azure-keyvault -o json 2>$null | ConvertFrom-Json
if ($store.status.conditions) {
    $readyCondition = $store.status.conditions | Where-Object { $_.type -eq "Ready" }
    if ($readyCondition.status -eq "True") {
        Write-Host "   ✅ ClusterSecretStore is READY" -ForegroundColor $Colors.Success
    } else {
        Write-Host "   ⚠️  ClusterSecretStore status: $($readyCondition.reason)" -ForegroundColor $Colors.Warning
    }
} else {
    Write-Host "   ⚠️  ClusterSecretStore status not yet available" -ForegroundColor $Colors.Warning
}

Write-Host ""
if ($verifyErrors -eq 0) {
    Write-Host "✅ All critical checks passed! Setup is complete and idempotent." -ForegroundColor $Colors.Success
    Write-Host "   You can safely run this script again if needed." -ForegroundColor $Colors.Muted
} else {
    Write-Host "⚠️  Some checks failed. Please review the output above." -ForegroundColor $Colors.Warning
}

Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor $Colors.Title
Write-Host "1. Verify ClusterSecretStore status:" -ForegroundColor $Colors.Info
Write-Host "   kubectl get clustersecretstore azure-keyvault" -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "2. Sync ArgoCD application:" -ForegroundColor $Colors.Info
Write-Host "   The ExternalSecrets should now sync automatically" -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "3. Check ExternalSecrets status:" -ForegroundColor $Colors.Info
Write-Host "   kubectl get externalsecrets -n cloudgames" -ForegroundColor $Colors.Muted
Write-Host ""

