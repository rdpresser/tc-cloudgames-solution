<#
.SYNOPSIS
  Applies Workload Identity migration to AKS cluster.

.DESCRIPTION
  This script helps migrate from connection string authentication to 
  Workload Identity for Service Bus. It updates ServiceAccounts with 
  the correct client IDs from Terraform outputs.

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER TerraformDir
  Path to Terraform foundation directory.

.EXAMPLE
  .\apply-workload-identity.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "tc-cloudgames-solution-dev-rg",

    [Parameter(Mandatory = $false)]
    [string]$TerraformDir = "..\..\..\terraform\foundation"
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
    Write-Host "  Workload Identity Migration - Apply Changes" -ForegroundColor $Colors.Title
    Write-Host "============================================================" -ForegroundColor $Colors.Title
    Write-Host ""
}

Show-Header

# =============================================================================
# Step 1: Get Terraform Outputs
# =============================================================================
Write-Host "=== 1/4 Getting Terraform Outputs ===" -ForegroundColor $Colors.Title
Write-Host ""

if (-not (Test-Path $TerraformDir)) {
    Write-Host "❌ Terraform directory not found: $TerraformDir" -ForegroundColor $Colors.Error
    exit 1
}

Push-Location $TerraformDir

try {
    Write-Host "Retrieving Client IDs from Terraform..." -ForegroundColor $Colors.Info
    
    $userApiClientId = terraform output -raw user_api_client_id 2>$null
    $gamesApiClientId = terraform output -raw games_api_client_id 2>$null
    $paymentsApiClientId = terraform output -raw payments_api_client_id 2>$null

    if (-not $userApiClientId -or -not $gamesApiClientId -or -not $paymentsApiClientId) {
        Write-Host "❌ Failed to retrieve Client IDs. Run 'terraform apply' first." -ForegroundColor $Colors.Error
        exit 1
    }

    Write-Host "✅ User API Client ID    : $userApiClientId" -ForegroundColor $Colors.Success
    Write-Host "✅ Games API Client ID   : $gamesApiClientId" -ForegroundColor $Colors.Success
    Write-Host "✅ Payments API Client ID: $paymentsApiClientId" -ForegroundColor $Colors.Success

} finally {
    Pop-Location
}

# =============================================================================
# Step 2: Update ServiceAccount YAMLs
# =============================================================================
Write-Host ""
Write-Host "=== 2/4 Updating ServiceAccount Manifests ===" -ForegroundColor $Colors.Title
Write-Host ""

$baseDir = "..\..\base"

# Track if any ServiceAccount update failed
$updatesFailed = $false

# Update user-api ServiceAccount
$userSaPath = Join-Path $baseDir "user\service-account.yaml"
if (Test-Path $userSaPath) {
    $content = Get-Content $userSaPath -Raw
    $content = $content -replace 'REPLACE_WITH_USER_API_CLIENT_ID', $userApiClientId
    Set-Content $userSaPath -Value $content -NoNewline
    Write-Host "✅ Updated: user-api ServiceAccount" -ForegroundColor $Colors.Success
} else {
    Write-Host "❌ Not found: $userSaPath" -ForegroundColor $Colors.Error
    $updatesFailed = $true
}

# Update games-api ServiceAccount
$gamesSaPath = Join-Path $baseDir "games\service-account.yaml"
if (Test-Path $gamesSaPath) {
    $content = Get-Content $gamesSaPath -Raw
    $content = $content -replace 'REPLACE_WITH_GAMES_API_CLIENT_ID', $gamesApiClientId
    Set-Content $gamesSaPath -Value $content -NoNewline
    Write-Host "✅ Updated: games-api ServiceAccount" -ForegroundColor $Colors.Success
} else {
    Write-Host "❌ Not found: $gamesSaPath" -ForegroundColor $Colors.Error
    $updatesFailed = $true
}

# Update payments-api ServiceAccount
$paymentsSaPath = Join-Path $baseDir "payments\service-account.yaml"
if (Test-Path $paymentsSaPath) {
    $content = Get-Content $paymentsSaPath -Raw
    $content = $content -replace 'REPLACE_WITH_PAYMENTS_API_CLIENT_ID', $paymentsApiClientId
    Set-Content $paymentsSaPath -Value $content -NoNewline
    Write-Host "✅ Updated: payments-api ServiceAccount" -ForegroundColor $Colors.Success
} else {
    Write-Host "❌ Not found: $paymentsSaPath" -ForegroundColor $Colors.Error
    $updatesFailed = $true
}

# Exit if any ServiceAccount update failed
if ($updatesFailed) {
    Write-Host "" -ForegroundColor $Colors.Error
    Write-Host "❌ Failed to update all ServiceAccounts. Check paths and try again." -ForegroundColor $Colors.Error
    exit 1
}

# =============================================================================
# Step 3: Validate Kubernetes Connection
# =============================================================================
Write-Host ""
Write-Host "=== 3/4 Validating Kubernetes Connection ===" -ForegroundColor $Colors.Title
Write-Host ""

try {
    $clusterInfo = kubectl cluster-info 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Not connected" }
    Write-Host "✅ Connected to Kubernetes cluster" -ForegroundColor $Colors.Success
} catch {
    Write-Host "❌ Not connected to Kubernetes. Run: az aks get-credentials" -ForegroundColor $Colors.Error
    exit 1
}

# =============================================================================
# Step 4: Show Next Steps
# =============================================================================
Write-Host ""
Write-Host "=== 4/4 Next Steps ===" -ForegroundColor $Colors.Title
Write-Host ""

Write-Host "ServiceAccounts updated with Client IDs. To apply changes:" -ForegroundColor $Colors.Info
Write-Host ""
Write-Host "  1. Review changes:" -ForegroundColor $Colors.Muted
Write-Host "     git diff" -ForegroundColor $Colors.Warning
Write-Host ""
Write-Host "  2. Apply manually:" -ForegroundColor $Colors.Muted
Write-Host "     kubectl apply -k ../../overlays/prod/" -ForegroundColor $Colors.Warning
Write-Host ""
Write-Host "  3. OR commit + push for ArgoCD:" -ForegroundColor $Colors.Muted
Write-Host "     git add ." -ForegroundColor $Colors.Warning
Write-Host "     git commit -m 'feat: migrate to Workload Identity for Service Bus'" -ForegroundColor $Colors.Warning
Write-Host "     git push origin feature/phase_04" -ForegroundColor $Colors.Warning
Write-Host ""
Write-Host "  4. Monitor pods:" -ForegroundColor $Colors.Muted
Write-Host "     kubectl get pods -n cloudgames -w" -ForegroundColor $Colors.Warning
Write-Host ""
Write-Host "⚠️  WARNING: Pods will restart during this operation (~30-60s downtime)" -ForegroundColor $Colors.Warning
Write-Host ""

Write-Host "============================================================" -ForegroundColor $Colors.Success
Write-Host "  ServiceAccounts ready for deployment!" -ForegroundColor $Colors.Success
Write-Host "============================================================" -ForegroundColor $Colors.Success
Write-Host ""
