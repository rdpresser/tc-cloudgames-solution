<#
.SYNOPSIS
  Updates federated identity credentials after AKS recreation.

.DESCRIPTION
  When you recreate an AKS cluster, the OIDC Issuer URL changes.
  This script updates all federated identity credentials to point to the new issuer:
  - External Secrets Operator
  - (Future: API service accounts if they also use federated credentials)

.EXAMPLE
  .\fix-federated-credentials-after-aks-recreation.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "tc-cloudgames-solution-dev-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "tc-cloudgames-dev-cr8n-aks"
)

$ErrorActionPreference = "Stop"

$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Muted   = "Gray"
    Title   = "Magenta"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
Write-Host "║   🔄 Fix Federated Credentials After AKS Recreate        ║" -ForegroundColor $Colors.Title
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
Write-Host ""

# Get new OIDC Issuer URL
Write-Host "📌 Getting new OIDC Issuer URL from AKS..." -ForegroundColor $Colors.Info
$oidcIssuer = az aks show `
    --resource-group $ResourceGroup `
    --name $ClusterName `
    --query "oidcIssuerProfile.issuerUrl" `
    -o tsv

if (-not $oidcIssuer) {
    Write-Host "❌ Failed to get OIDC Issuer URL" -ForegroundColor $Colors.Error
    Write-Host "   Make sure AKS cluster '$ClusterName' exists and OIDC is enabled" -ForegroundColor $Colors.Muted
    exit 1
}

Write-Host "  ✅ OIDC Issuer: $oidcIssuer" -ForegroundColor $Colors.Success
Write-Host ""

# Define federated credentials to update
$federatedCredentials = @(
    @{
        IdentityName = "tc-cloudgames-dev-cr8n-aks-eso-identity"
        FedCredName  = "tc-cloudgames-dev-cr8n-aks-eso-identity-federated-credential"
        Subject      = "system:serviceaccount:external-secrets:external-secrets-operator"
        Description  = "External Secrets Operator"
    }
)

Write-Host "🔧 Updating federated identity credentials..." -ForegroundColor $Colors.Info
Write-Host ""

foreach ($cred in $federatedCredentials) {
    Write-Host "  📋 $($cred.Description)" -ForegroundColor $Colors.Info
    Write-Host "     Identity: $($cred.IdentityName)" -ForegroundColor $Colors.Muted
    Write-Host "     Subject:  $($cred.Subject)" -ForegroundColor $Colors.Muted
    
    # Check if identity exists
    $identity = az identity show `
        --name $cred.IdentityName `
        --resource-group $ResourceGroup `
        2>$null | ConvertFrom-Json
    
    if (-not $identity) {
        Write-Host "     ⚠️  Identity not found, skipping..." -ForegroundColor $Colors.Warning
        Write-Host ""
        continue
    }
    
    # Check current federated credential
    $currentCred = az identity federated-credential show `
        --identity-name $cred.IdentityName `
        --resource-group $ResourceGroup `
        --name $cred.FedCredName `
        2>$null | ConvertFrom-Json
    
    if ($currentCred) {
        $currentIssuer = $currentCred.issuer
        Write-Host "     Current issuer: $currentIssuer" -ForegroundColor $Colors.Muted
        
        if ($currentIssuer -eq $oidcIssuer) {
            Write-Host "     ✅ Already up-to-date, skipping..." -ForegroundColor $Colors.Success
            Write-Host ""
            continue
        }
        
        Write-Host "     🔄 Deleting old federated credential..." -ForegroundColor $Colors.Warning
        az identity federated-credential delete `
            --identity-name $cred.IdentityName `
            --resource-group $ResourceGroup `
            --name $cred.FedCredName `
            --yes `
            2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "     ✅ Old credential deleted" -ForegroundColor $Colors.Success
        }
        else {
            Write-Host "     ⚠️  Failed to delete old credential" -ForegroundColor $Colors.Warning
        }
    }
    
    # Create new federated credential
    Write-Host "     ➕ Creating new federated credential..." -ForegroundColor $Colors.Info
    $result = az identity federated-credential create `
        --identity-name $cred.IdentityName `
        --resource-group $ResourceGroup `
        --name $cred.FedCredName `
        --issuer $oidcIssuer `
        --subject $cred.Subject `
        --audiences "api://AzureADTokenExchange" `
        2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "     ✅ New credential created with updated issuer" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "     ❌ Failed to create new credential" -ForegroundColor $Colors.Error
        Write-Host "     Error: $result" -ForegroundColor $Colors.Muted
    }
    
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Success
Write-Host "║   ✅ Federated Credentials Updated                       ║" -ForegroundColor $Colors.Success
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Success
Write-Host ""

Write-Host "📋 Next steps:" -ForegroundColor $Colors.Info
Write-Host "  1. Restart ESO pods: kubectl rollout restart deployment -n external-secrets" -ForegroundColor $Colors.Muted
Write-Host "  2. Check ClusterSecretStore: kubectl get clustersecretstore azure-keyvault" -ForegroundColor $Colors.Muted
Write-Host "  3. Verify ExternalSecrets: kubectl get externalsecrets -A" -ForegroundColor $Colors.Muted
Write-Host ""
