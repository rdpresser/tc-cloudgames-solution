<#
.SYNOPSIS
  Installs External Secrets Operator on AKS cluster.

.DESCRIPTION
  Installs External Secrets Operator using Helm with production-ready configuration.
  Supports idempotent operations with -Force parameter for reinstallation.

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER ClusterName
  AKS cluster name.

.PARAMETER Force
  Forces reinstallation by uninstalling existing release first.
  Default behavior is to upgrade in-place.

.EXAMPLE
  .\install-external-secrets.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"

.EXAMPLE
  .\install-external-secrets.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  External Secrets Operator Installation" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Prerequisites Check
# =============================================================================
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

foreach ($cmd in @("az", "kubectl", "helm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "❌ ERROR: '$cmd' not found. Please install it first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All prerequisites available" -ForegroundColor Green

# =============================================================================
# Connect to AKS
# =============================================================================
Write-Host ""
Write-Host "Connecting to AKS cluster..." -ForegroundColor Yellow

az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get AKS credentials" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connected to cluster: $ClusterName" -ForegroundColor Green

# =============================================================================
# Check Existing Installation
# =============================================================================
$namespace = "external-secrets"
$chartVersion = "0.9.11"

Write-Host ""
Write-Host "Checking for existing External Secrets installation..." -ForegroundColor Yellow

$existingRelease = helm list -n $namespace -q 2>$null | Where-Object { $_ -match "external-secrets" }

if ($existingRelease) {
    if ($Force) {
        Write-Host "🔄 Force mode: Uninstalling existing ESO release..." -ForegroundColor Yellow
        helm uninstall $existingRelease -n $namespace --wait 2>$null
        
        Write-Host "   Deleting namespace..." -ForegroundColor Gray
        kubectl delete namespace $namespace --timeout=60s 2>$null
        
        Start-Sleep -Seconds 5
        Write-Host "✅ Existing installation removed" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  External Secrets already installed - performing in-place upgrade" -ForegroundColor Cyan
    }
} else {
    Write-Host "ℹ️  No existing installation found - performing fresh install" -ForegroundColor Cyan
}

# =============================================================================
# Add Helm Repository
# =============================================================================
Write-Host ""
Write-Host "Configuring Helm repository..." -ForegroundColor Yellow

helm repo add external-secrets https://charts.external-secrets.io 2>$null
helm repo update

Write-Host "✅ Helm repository configured" -ForegroundColor Green

# =============================================================================
# Create Namespace
# =============================================================================
Write-Host ""
Write-Host "Ensuring namespace exists..." -ForegroundColor Yellow

kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -

Write-Host "✅ Namespace ready: $namespace" -ForegroundColor Green

# =============================================================================
# Install/Upgrade External Secrets Operator
# =============================================================================
Write-Host ""
Write-Host "Installing External Secrets Operator (version $chartVersion)..." -ForegroundColor Yellow
Write-Host ""

helm upgrade --install external-secrets external-secrets/external-secrets `
    --namespace $namespace `
    --version $chartVersion `
    --set installCRDs=true `
    --set webhook.port=9443 `
    --set resources.limits.cpu=200m `
    --set resources.limits.memory=256Mi `
    --set resources.requests.cpu=100m `
    --set resources.requests.memory=128Mi `
    --wait `
    --timeout 5m

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Helm installation failed" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Wait for Pods
# =============================================================================
Write-Host ""
Write-Host "Waiting for pods to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "✅ External Secrets Operator installed successfully" -ForegroundColor Green

# =============================================================================
# Summary
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure Workload Identity for ESO" -ForegroundColor Gray
Write-Host "     Run: .\setup-eso-workload-identity.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Create ClusterSecretStore to connect to Azure Key Vault" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Create ExternalSecret resources in your namespaces" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# Verification
# =============================================================================
Write-Host "📊 Current Status:" -ForegroundColor Cyan
Write-Host ""
kubectl get pods -n $namespace
Write-Host ""
kubectl get crds | Select-String "external-secrets"

Write-Host ""
