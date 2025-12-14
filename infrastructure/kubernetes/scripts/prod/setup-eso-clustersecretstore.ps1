<#
.SYNOPSIS
  Configure External Secrets Operator ClusterSecretStore for Azure Key Vault.

.DESCRIPTION
  Creates a ClusterSecretStore resource that connects ESO to Azure Key Vault
  using AKS Managed Identity (Workload Identity or Kubelet Identity).

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER ClusterName
  AKS Cluster name.

.PARAMETER KeyVaultName
  Azure Key Vault name.

.PARAMETER Force
  Force recreation if ClusterSecretStore already exists.

.EXAMPLE
  .\setup-eso-clustersecretstore.ps1 -ResourceGroup "my-rg" -ClusterName "my-aks" -KeyVaultName "my-kv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "tc-cloudgames-solution-dev-rg",

    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "tc-cloudgames-dev-cr8n-aks",

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "tccloudgamesdevcr8nkv",

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

function Show-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Colors.Title
    Write-Host "  External Secrets Operator - ClusterSecretStore Setup" -ForegroundColor $Colors.Title
    Write-Host "============================================================" -ForegroundColor $Colors.Title
    Write-Host ""
    Write-Host "Resource Group : $ResourceGroup" -ForegroundColor $Colors.Muted
    Write-Host "Cluster Name   : $ClusterName" -ForegroundColor $Colors.Muted
    Write-Host "Key Vault      : $KeyVaultName" -ForegroundColor $Colors.Muted
    Write-Host ""
}

Show-Header

Write-Host "=== 1/5 Checking prerequisites ===" -ForegroundColor $Colors.Title
try {
    kubectl cluster-info 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cluster not accessible" }
    Write-Host "✅ Kubernetes cluster accessible" -ForegroundColor $Colors.Success
} catch {
    Write-Host "❌ Kubernetes cluster not accessible" -ForegroundColor $Colors.Error
    exit 1
}

$esoPods = kubectl get pods -n external-secrets --no-headers 2>$null | Where-Object { $_ -match "Running" }
if (-not $esoPods) {
    Write-Host "❌ External Secrets Operator not found or not running" -ForegroundColor $Colors.Error
    Write-Host "   Run: .\aks-manager.ps1 install-eso" -ForegroundColor $Colors.Muted
    exit 1
}
Write-Host "✅ External Secrets Operator is running" -ForegroundColor $Colors.Success

Write-Host ""
Write-Host "=== 2/5 Getting Azure information ===" -ForegroundColor $Colors.Title

try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) { throw "Not logged in" }
    Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor $Colors.Success
} catch {
    Write-Host "❌ Not logged in to Azure CLI" -ForegroundColor $Colors.Error
    Write-Host "   Run: az login" -ForegroundColor $Colors.Muted
    exit 1
}

$tenantId = az account show --query tenantId -o tsv
Write-Host "   Tenant ID: $tenantId" -ForegroundColor $Colors.Muted

$aks = az aks show --resource-group $ResourceGroup --name $ClusterName 2>$null | ConvertFrom-Json
if (-not $aks) {
    Write-Host "❌ AKS cluster not found" -ForegroundColor $Colors.Error
    exit 1
}

$clientId = $aks.identityProfile.kubeletidentity.clientId
Write-Host "   Kubelet Identity Client ID: $clientId" -ForegroundColor $Colors.Muted

$kvUrl = "https://$KeyVaultName.vault.azure.net/"
Write-Host "   Key Vault URL: $kvUrl" -ForegroundColor $Colors.Muted

Write-Host ""
Write-Host "=== 3/5 Checking Key Vault access ===" -ForegroundColor $Colors.Title

# Check if Key Vault exists
$kv = az keyvault show --name $KeyVaultName 2>$null | ConvertFrom-Json
if (-not $kv) {
    Write-Host "❌ Key Vault '$KeyVaultName' not found" -ForegroundColor $Colors.Error
    exit 1
}
Write-Host "✅ Key Vault '$KeyVaultName' found" -ForegroundColor $Colors.Success

# Grant access to Managed Identity if not already granted
Write-Host "   Granting Key Vault access to Managed Identity..." -ForegroundColor $Colors.Info
az keyvault set-policy --name $KeyVaultName --object-id $aks.identityProfile.kubeletidentity.objectId --secret-permissions get list 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Key Vault access granted" -ForegroundColor $Colors.Success
} else {
    Write-Host "⚠️  Failed to set Key Vault policy (might already exist)" -ForegroundColor $Colors.Warning
}

Write-Host ""
Write-Host "=== 4/5 Creating ClusterSecretStore ===" -ForegroundColor $Colors.Title

# Check if already exists
$existing = kubectl get clustersecretstore azure-keyvault 2>$null
if ($existing -and -not $Force) {
    Write-Host "⚠️  ClusterSecretStore 'azure-keyvault' already exists" -ForegroundColor $Colors.Warning
    $response = Read-Host "Do you want to recreate it? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "   Skipping creation" -ForegroundColor $Colors.Muted
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $Colors.Title
        Write-Host "  ClusterSecretStore already configured!" -ForegroundColor $Colors.Success
        Write-Host "============================================================" -ForegroundColor $Colors.Title
        exit 0
    }
    kubectl delete clustersecretstore azure-keyvault 2>$null
    Write-Host "   Deleted existing ClusterSecretStore" -ForegroundColor $Colors.Info
}

# Create ClusterSecretStore manifest
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
      authType: ManagedIdentity
      vaultUrl: $kvUrl
      tenantId: $tenantId
      identityId: $clientId
"@

# Apply manifest
$tempFile = [System.IO.Path]::GetTempFileName()
$manifest | Out-File -FilePath $tempFile -Encoding utf8
kubectl apply -f $tempFile 2>&1 | Out-Null
Remove-Item $tempFile -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ ClusterSecretStore 'azure-keyvault' created" -ForegroundColor $Colors.Success
} else {
    Write-Host "❌ Failed to create ClusterSecretStore" -ForegroundColor $Colors.Error
    exit 1
}

Write-Host ""
Write-Host "=== 5/5 Verifying ClusterSecretStore ===" -ForegroundColor $Colors.Title

Start-Sleep -Seconds 3

$store = kubectl get clustersecretstore azure-keyvault -o json 2>$null | ConvertFrom-Json
if ($store) {
    Write-Host "✅ ClusterSecretStore verified:" -ForegroundColor $Colors.Success
    kubectl get clustersecretstore azure-keyvault
    
    Write-Host ""
    Write-Host "   Status conditions:" -ForegroundColor $Colors.Info
    if ($store.status.conditions) {
        $store.status.conditions | ForEach-Object {
            $icon = if ($_.status -eq "True") { "✅" } else { "❌" }
            Write-Host "   $icon Type: $($_.type) | Status: $($_.status) | Reason: $($_.reason)" -ForegroundColor $(if ($_.status -eq "True") { $Colors.Success } else { $Colors.Warning })
        }
    } else {
        Write-Host "   ⏳ Status not yet available (may take a few seconds)" -ForegroundColor $Colors.Warning
    }
} else {
    Write-Host "⚠️  ClusterSecretStore created but not yet visible" -ForegroundColor $Colors.Warning
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor $Colors.Title
Write-Host "  ClusterSecretStore Setup Complete!" -ForegroundColor $Colors.Success
Write-Host "============================================================" -ForegroundColor $Colors.Title
Write-Host ""

Write-Host "📋 Next Steps:" -ForegroundColor $Colors.Title
Write-Host ""
Write-Host "1. Test the ClusterSecretStore:" -ForegroundColor $Colors.Info
Write-Host "   kubectl get clustersecretstore azure-keyvault" -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "2. Create an ExternalSecret to fetch secrets from Key Vault:" -ForegroundColor $Colors.Info
Write-Host @"
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: cloudgames
spec:
  secretStoreRef:
    name: azure-keyvault
    kind: ClusterSecretStore
  target:
    name: app-secret
  data:
  - secretKey: connection-string
    remoteRef:
      key: database-connection-string
"@ -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "3. Verify ExternalSecret sync:" -ForegroundColor $Colors.Info
Write-Host "   kubectl get externalsecret -n cloudgames" -ForegroundColor $Colors.Muted
Write-Host "   kubectl get secret -n cloudgames" -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "4. Bootstrap ArgoCD applications:" -ForegroundColor $Colors.Info
Write-Host "   .\aks-manager.ps1 bootstrap" -ForegroundColor $Colors.Muted
Write-Host ""
