<#
.SYNOPSIS
  Executes complete infrastructure setup after Terraform apply.
  
.DESCRIPTION
  This script automates all necessary steps after the initial Terraform apply:
  1. Connects to AKS cluster
  2. Installs NGINX Ingress Controller
  3. Retrieves LoadBalancer IP
  4. Installs External Secrets Operator
  5. Configures Workload Identity
  6. Deploys applications via Kustomize
  
.PARAMETER ResourceGroup
  Azure Resource Group name.
  
.PARAMETER ClusterName
  AKS cluster name.
  
.PARAMETER Environment
  Environment: dev, staging, prod
  Default: dev
  
.PARAMETER SkipNginx
  Skip NGINX Ingress installation (if already installed).
  
.PARAMETER SkipDeploy
  Skip application deployment.

.PARAMETER Force
  Reinstalls components (NGINX/ESO) even if already installed.
  
.EXAMPLE
  .\setup-complete-infrastructure.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.EXAMPLE
  .\setup-complete-infrastructure.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -SkipNginx
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipNginx,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$k8sDir = Split-Path (Split-Path $scriptDir -Parent) -Parent

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  TC CloudGames - Complete Infrastructure Setup" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Environment    : $Environment" -ForegroundColor White
Write-Host ""

# =============================================================================
# 1. Connect to AKS
# =============================================================================
Write-Host ""
Write-Host "=== Step 1/6: Connecting to AKS ===" -ForegroundColor Yellow
Write-Host ""

az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to connect to AKS cluster" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connected to AKS cluster" -ForegroundColor Green
kubectl cluster-info

# =============================================================================
# 2. Install NGINX Ingress
# =============================================================================
$nginxIP = $null

if (-not $SkipNginx) {
    Write-Host ""
    Write-Host "=== Step 2/6: Installing NGINX Ingress Controller ===" -ForegroundColor Yellow
    Write-Host ""

    $installArgs = @{
        ResourceGroup = $ResourceGroup
        ClusterName = $ClusterName
    }
    if ($Force) { $installArgs['Force'] = $true }

    & "$scriptDir\install-nginx-ingress.ps1" @installArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ NGINX Ingress installation failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "=== Step 2/6: Skipping NGINX Ingress (already installed) ===" -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# 3. Get NGINX LoadBalancer IP
# =============================================================================
Write-Host ""
Write-Host "=== Step 3/6: Getting NGINX LoadBalancer IP ===" -ForegroundColor Yellow
Write-Host ""

$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts -and -not $nginxIP) {
    $attempt++
    $svc = kubectl get svc ingress-nginx-controller -n ingress-nginx -o json 2>$null | ConvertFrom-Json
    if ($svc -and $svc.status.loadBalancer.ingress) {
        $nginxIP = $svc.status.loadBalancer.ingress[0].ip
    }
    
    if (-not $nginxIP) {
        Write-Host "   Waiting for LoadBalancer IP... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

if (-not $nginxIP) {
    Write-Host "❌ Failed to get NGINX LoadBalancer IP" -ForegroundColor Red
    exit 1
}

Write-Host "✅ NGINX LoadBalancer IP: $nginxIP" -ForegroundColor Green

# =============================================================================
# 4. Install External Secrets Operator
# =============================================================================
Write-Host ""
Write-Host "=== Step 4/6: Installing External Secrets Operator ===" -ForegroundColor Yellow
Write-Host ""

$installArgs = @{
    ResourceGroup = $ResourceGroup
    ClusterName = $ClusterName
}
if ($Force) { $installArgs['Force'] = $true }

& "$scriptDir\install-external-secrets.ps1" @installArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ External Secrets Operator installation failed" -ForegroundColor Red
    exit 1
}

# =============================================================================
# 5. Setup Workload Identity for ESO
# =============================================================================
Write-Host ""
Write-Host "=== Step 5/6: Configuring Workload Identity ===" -ForegroundColor Yellow
Write-Host ""

$keyVaultName = if ($KeyVaultName) { $KeyVaultName } else { "tccloudgamesdevcr8nkv" }

& "$scriptDir\setup-eso-workload-identity.ps1" `
    -ResourceGroup $ResourceGroup `
    -ClusterName $ClusterName `
    -KeyVaultName $keyVaultName

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure Workload Identity" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Workload Identity configured" -ForegroundColor Green

# =============================================================================
# 6. Deploy Applications
# =============================================================================
if (-not $SkipDeploy) {
    Write-Host ""
    Write-Host "=== Step 6/6: Deploying Applications ===" -ForegroundColor Yellow
    Write-Host ""
    
    $overlayPath = Join-Path $k8sDir "overlays/$Environment"
    
    if (-not (Test-Path $overlayPath)) {
        Write-Host "❌ Overlay path not found: $overlayPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Applying Kustomize overlay: $Environment" -ForegroundColor Cyan
    kubectl apply -k $overlayPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to deploy applications" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Applications deployed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting for pods to be ready..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    Write-Host ""
    kubectl get pods -n cloudgames
} else {
    Write-Host ""
    Write-Host "=== Step 6/6: Skipping Application Deployment ===" -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# Summary
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 NGINX Ingress IP: $nginxIP" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Verification Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Check pods status" -ForegroundColor Gray
Write-Host "  kubectl get pods -n cloudgames" -ForegroundColor White
Write-Host ""
Write-Host "  # Check External Secrets" -ForegroundColor Gray
Write-Host "  kubectl get externalsecrets -n cloudgames" -ForegroundColor White
Write-Host ""
Write-Host "  # Check Ingress" -ForegroundColor Gray
Write-Host "  kubectl get ingress -n cloudgames" -ForegroundColor White
Write-Host ""
Write-Host "  # Test health endpoints" -ForegroundColor Gray
Write-Host "  curl http://$nginxIP/health -H 'Host: games-api.cloudgames.local'" -ForegroundColor White
Write-Host "  curl http://$nginxIP/health -H 'Host: user-api.cloudgames.local'" -ForegroundColor White
Write-Host "  curl http://$nginxIP/health -H 'Host: payments-api.cloudgames.local'" -ForegroundColor White
Write-Host ""
Write-Host "📚 Documentation: infrastructure/kubernetes/scripts/prod/README.md" -ForegroundColor Cyan
Write-Host ""
