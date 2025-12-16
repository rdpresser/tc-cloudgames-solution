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
$EsoServiceAccount = "external-secrets"

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
$esoPods = kubectl get pods -n $EsoNamespace --no-headers 2>$null | Where-Object { $_ -match "Running" }
if (-not $esoPods) {
    Write-Host "❌ External Secrets Operator not running" -ForegroundColor $Colors.Error
    Write-Host "   Run: .\aks-manager.ps1 install-eso" -ForegroundColor $Colors.Muted
    exit 1
}
Write-Host "✅ External Secrets Operator is running" -ForegroundColor $Colors.Success

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
# Step 3: Create User Assigned Identity
# =============================================================================
Write-Host ""
Write-Host "=== 3/7 Creating User Assigned Identity ===" -ForegroundColor $Colors.Title

# Check if identity exists (suppress errors)
$ErrorActionPreference = "SilentlyContinue"
$existingIdentityJson = az identity show --name $IdentityName --resource-group $ResourceGroup 2>&1
$ErrorActionPreference = "Stop"

$existingIdentity = $null
if ($LASTEXITCODE -eq 0 -and $existingIdentityJson) {
    try {
        $existingIdentity = $existingIdentityJson | ConvertFrom-Json
    } catch {
        $existingIdentity = $null
    }
}

if ($existingIdentity -and $existingIdentity.clientId) {
    Write-Host "⚠️  Identity '$IdentityName' already exists" -ForegroundColor $Colors.Warning
    $clientId = $existingIdentity.clientId
    $principalId = $existingIdentity.principalId
    Write-Host "   Client ID: $clientId" -ForegroundColor $Colors.Muted
} else {
    Write-Host "   Creating identity '$IdentityName'..." -ForegroundColor $Colors.Info
    $identityJson = az identity create --name $IdentityName --resource-group $ResourceGroup --location $aks.location 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create identity: $identityJson" -ForegroundColor $Colors.Error
        exit 1
    }
    $identity = $identityJson | ConvertFrom-Json
    $clientId = $identity.clientId
    $principalId = $identity.principalId
    Write-Host "✅ Identity created: $clientId" -ForegroundColor $Colors.Success

    # Wait for identity to propagate
    Write-Host "   Waiting for identity to propagate..." -ForegroundColor $Colors.Muted
    Start-Sleep -Seconds 15
}

# =============================================================================
# Step 4: Create Federated Identity Credential
# =============================================================================
Write-Host ""
Write-Host "=== 4/7 Creating Federated Identity Credential ===" -ForegroundColor $Colors.Title

$fedCredName = "$IdentityName-federated-credential"
$subject = "system:serviceaccount:${EsoNamespace}:${EsoServiceAccount}"

# Check if federated credential exists (suppress errors)
$ErrorActionPreference = "SilentlyContinue"
$existingFedCredJson = az identity federated-credential show --name $fedCredName --identity-name $IdentityName --resource-group $ResourceGroup 2>&1
$ErrorActionPreference = "Stop"

$existingFedCred = $null
if ($LASTEXITCODE -eq 0 -and $existingFedCredJson) {
    try {
        $existingFedCred = $existingFedCredJson | ConvertFrom-Json
    } catch {
        $existingFedCred = $null
    }
}

if ($existingFedCred -and $existingFedCred.name) {
    Write-Host "⚠️  Federated credential already exists" -ForegroundColor $Colors.Warning
} else {
    Write-Host "   Creating federated credential..." -ForegroundColor $Colors.Info
    Write-Host "   Subject: $subject" -ForegroundColor $Colors.Muted

    az identity federated-credential create `
        --name $fedCredName `
        --identity-name $IdentityName `
        --resource-group $ResourceGroup `
        --issuer $oidcIssuerUrl `
        --subject $subject `
        --audiences "api://AzureADTokenExchange" 2>$null | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create federated credential" -ForegroundColor $Colors.Error
        exit 1
    }
    Write-Host "✅ Federated credential created" -ForegroundColor $Colors.Success
}

# =============================================================================
# Step 5: Grant Key Vault Access
# =============================================================================
Write-Host ""
Write-Host "=== 5/7 Granting Key Vault access ===" -ForegroundColor $Colors.Title

$kv = az keyvault show --name $KeyVaultName 2>$null | ConvertFrom-Json
if (-not $kv) {
    Write-Host "❌ Key Vault '$KeyVaultName' not found" -ForegroundColor $Colors.Error
    exit 1
}

Write-Host "   Assigning 'Key Vault Secrets User' role..." -ForegroundColor $Colors.Info
az role assignment create `
    --role "Key Vault Secrets User" `
    --assignee-object-id $principalId `
    --assignee-principal-type ServicePrincipal `
    --scope $kv.id 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Key Vault access granted" -ForegroundColor $Colors.Success
} else {
    Write-Host "⚠️  Role assignment may already exist" -ForegroundColor $Colors.Warning
}

# =============================================================================
# Step 6: Annotate ESO ServiceAccount
# =============================================================================
Write-Host ""
Write-Host "=== 6/7 Annotating ESO ServiceAccount ===" -ForegroundColor $Colors.Title

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
kubectl annotate serviceaccount external-secrets-webhook -n $EsoNamespace `
    "azure.workload.identity/client-id=$clientId" --overwrite 2>$null
kubectl annotate serviceaccount external-secrets-webhook -n $EsoNamespace `
    "azure.workload.identity/tenant-id=$tenantId" --overwrite 2>$null
kubectl label serviceaccount external-secrets-webhook -n $EsoNamespace `
    "azure.workload.identity/use=true" --overwrite 2>$null

Write-Host "✅ Webhook ServiceAccount also annotated" -ForegroundColor $Colors.Success

# Restart ESO pods to pick up the new identity
Write-Host "   Restarting ESO pods..." -ForegroundColor $Colors.Info
kubectl rollout restart deployment/external-secrets -n $EsoNamespace 2>$null
kubectl rollout restart deployment/external-secrets-webhook -n $EsoNamespace 2>$null
kubectl rollout restart deployment/external-secrets-cert-controller -n $EsoNamespace 2>$null

Write-Host "   Waiting for pods to be ready..." -ForegroundColor $Colors.Muted
kubectl rollout status deployment/external-secrets -n $EsoNamespace --timeout=120s 2>$null

# =============================================================================
# Step 7: Recreate ClusterSecretStore
# =============================================================================
Write-Host ""
Write-Host "=== 7/7 Recreating ClusterSecretStore ===" -ForegroundColor $Colors.Title

$kvUrl = "https://$KeyVaultName.vault.azure.net"

$manifest = @"
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-keyvault
  labels:
    app.kubernetes.io/part-of: cloudgames
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: $kvUrl
      tenantId: $tenantId
      serviceAccountRef:
        name: $EsoServiceAccount
        namespace: $EsoNamespace
"@

# Delete and recreate
kubectl delete clustersecretstore azure-keyvault 2>$null
Start-Sleep -Seconds 2

$tempFile = [System.IO.Path]::GetTempFileName()
$manifest | Out-File -FilePath $tempFile -Encoding utf8
kubectl apply -f $tempFile 2>&1 | Out-Null
Remove-Item $tempFile -Force

Write-Host "✅ ClusterSecretStore recreated" -ForegroundColor $Colors.Success

# Wait and verify
Write-Host "   Waiting for ClusterSecretStore to be ready..." -ForegroundColor $Colors.Muted
Start-Sleep -Seconds 10

$store = kubectl get clustersecretstore azure-keyvault -o json 2>$null | ConvertFrom-Json
if ($store.status.conditions) {
    $readyCondition = $store.status.conditions | Where-Object { $_.type -eq "Ready" }
    if ($readyCondition.status -eq "True") {
        Write-Host "✅ ClusterSecretStore is READY!" -ForegroundColor $Colors.Success
    } else {
        Write-Host "⚠️  ClusterSecretStore status: $($readyCondition.reason)" -ForegroundColor $Colors.Warning
        Write-Host "   Message: $($readyCondition.message)" -ForegroundColor $Colors.Muted
    }
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

