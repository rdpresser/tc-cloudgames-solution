<#
.SYNOPSIS
  Installs NGINX Ingress Controller on AKS cluster.

.DESCRIPTION
  Installs NGINX Ingress Controller using Helm with production-ready configuration.
  Supports idempotent operations with -Force parameter for reinstallation.

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER ClusterName
  AKS cluster name.

.PARAMETER Force
  Forces reinstallation by uninstalling existing release first.
  Default behavior is to upgrade in-place.

.EXAMPLE
  .\install-nginx-ingress.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"

.EXAMPLE
  .\install-nginx-ingress.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -Force
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
Write-Host "  NGINX Ingress Controller Installation" -ForegroundColor Cyan
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
$namespace = "ingress-nginx"
$chartVersion = "4.11.3"

Write-Host ""
Write-Host "Checking for existing NGINX installation..." -ForegroundColor Yellow

$existingRelease = helm list -n $namespace -q 2>$null | Where-Object { $_ -match "ingress-nginx" }

if ($existingRelease) {
    if ($Force) {
        Write-Host "🔄 Force mode: Uninstalling existing NGINX release..." -ForegroundColor Yellow
        helm uninstall $existingRelease -n $namespace --wait 2>$null
        
        Write-Host "   Deleting namespace..." -ForegroundColor Gray
        kubectl delete namespace $namespace --timeout=60s 2>$null
        
        Start-Sleep -Seconds 5
        Write-Host "✅ Existing installation removed" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  NGINX Ingress already installed - performing in-place upgrade" -ForegroundColor Cyan
    }
} else {
    Write-Host "ℹ️  No existing installation found - performing fresh install" -ForegroundColor Cyan
}

# =============================================================================
# Add Helm Repository
# =============================================================================
Write-Host ""
Write-Host "Configuring Helm repository..." -ForegroundColor Yellow

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null
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
# Install/Upgrade NGINX Ingress
# =============================================================================
Write-Host ""
Write-Host "Installing NGINX Ingress Controller (version $chartVersion)..." -ForegroundColor Yellow
Write-Host ""

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
    --namespace $namespace `
    --version $chartVersion `
    --set controller.service.type=LoadBalancer `
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz `
    --set controller.metrics.enabled=true `
    --set controller.metrics.serviceMonitor.enabled=false `
    --set controller.resources.limits.cpu=500m `
    --set controller.resources.limits.memory=512Mi `
    --set controller.resources.requests.cpu=250m `
    --set controller.resources.requests.memory=256Mi `
    --set controller.admissionWebhooks.enabled=true `
    --set controller.admissionWebhooks.patch.enabled=true `
    --set defaultBackend.enabled=true `
    --set defaultBackend.resources.limits.cpu=50m `
    --set defaultBackend.resources.limits.memory=64Mi `
    --set defaultBackend.resources.requests.cpu=25m `
    --set defaultBackend.resources.requests.memory=32Mi `
    --wait `
    --timeout 10m

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Helm installation failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ NGINX Ingress Controller installed successfully" -ForegroundColor Green

# =============================================================================
# Wait for LoadBalancer IP
# =============================================================================
Write-Host ""
Write-Host "Waiting for LoadBalancer IP assignment..." -ForegroundColor Yellow

$maxAttempts = 30
$attempt = 0
$nginxIP = $null

while ($attempt -lt $maxAttempts -and -not $nginxIP) {
    $attempt++
    $svc = kubectl get svc ingress-nginx-controller -n $namespace -o json 2>$null | ConvertFrom-Json
    
    if ($svc -and $svc.status.loadBalancer.ingress) {
        $nginxIP = $svc.status.loadBalancer.ingress[0].ip
    }
    
    if (-not $nginxIP) {
        Write-Host "   Waiting... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

if ($nginxIP) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 NGINX Ingress LoadBalancer IP: $nginxIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Update Terraform variables with this IP" -ForegroundColor Gray
    Write-Host "  2. Re-run Terraform to configure APIM backends" -ForegroundColor Gray
    Write-Host "  3. Configure DNS to point to $nginxIP" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "⚠️  LoadBalancer IP not yet assigned after $maxAttempts attempts" -ForegroundColor Yellow
    Write-Host "   Check status with: kubectl get svc -n $namespace" -ForegroundColor Gray
    Write-Host ""
}

# =============================================================================
# Verification
# =============================================================================
Write-Host "📊 Current Status:" -ForegroundColor Cyan
Write-Host ""
kubectl get pods -n $namespace
Write-Host ""
kubectl get svc -n $namespace

Write-Host ""
