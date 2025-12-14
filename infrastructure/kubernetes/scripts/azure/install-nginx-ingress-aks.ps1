<#
.SYNOPSIS
  Installs NGINX Ingress Controller on Azure AKS cluster.
  
.DESCRIPTION
  This script installs NGINX Ingress Controller on an Azure AKS cluster using Helm.
  NGINX Ingress provides HTTP/HTTPS routing for Kubernetes services with a single
  LoadBalancer IP, reducing costs and centralizing TLS/SSL management.
  
  Features:
  - Installs NGINX Ingress via Helm
  - Configures Azure LoadBalancer with public IP
  - Sets up health probe paths
  - Enables metrics for Prometheus
  
.PARAMETER ResourceGroup
  Azure Resource Group name containing the AKS cluster.
  
.PARAMETER ClusterName
  Name of the AKS cluster.
  
.PARAMETER Namespace
  Kubernetes namespace for NGINX Ingress.
  Default: ingress-nginx
  
.PARAMETER ChartVersion
  NGINX Ingress Helm chart version.
  Default: 4.8.3
  
.PARAMETER Force
  Skip confirmation prompts and force reinstall if already exists.
  
.EXAMPLE
  .\install-nginx-ingress-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.NOTES
  Requirements:
  - Azure CLI (az) installed and logged in
  - kubectl installed
  - helm v3 installed
  
  Cost savings:
  - Without NGINX: 3 LoadBalancers ($40 each) = $120/month
  - With NGINX: 1 LoadBalancer = $40/month
  - Savings: $80/month (67%)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ingress-nginx",
    
    [Parameter(Mandatory = $false)]
    [string]$ChartVersion = "4.8.3",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  NGINX Ingress Controller Installation for Azure AKS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Namespace      : $Namespace" -ForegroundColor White
Write-Host "Chart Version  : $ChartVersion" -ForegroundColor White
Write-Host ""

# =============================================================================
# 0. Check if NGINX Ingress already exists
# =============================================================================
$existingRelease = helm list -n $Namespace -q 2>$null | Where-Object { $_ -match "ingress-nginx" }
if ($existingRelease -and -not $Force) {
    Write-Host "⚠️  NGINX Ingress Controller is already installed in namespace '$Namespace'" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to REINSTALL NGINX Ingress? This will DELETE and recreate it. (y/N)"
    
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "ℹ️  Installation cancelled. Existing NGINX Ingress installation preserved." -ForegroundColor Cyan
        exit 0
    }
    
    Write-Host ""
    Write-Host "🔄 Uninstalling existing NGINX Ingress..." -ForegroundColor Yellow
    helm uninstall $existingRelease -n $Namespace --wait 2>$null
    kubectl delete namespace $Namespace --timeout=60s 2>$null
    Start-Sleep -Seconds 5
}

# =============================================================================
# 1. Check Prerequisites
# =============================================================================
Write-Host "=== 1/6 Checking prerequisites ===" -ForegroundColor Yellow

foreach ($cmd in @("az", "kubectl", "helm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$cmd' not found. Please install it first." -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ All prerequisites installed" -ForegroundColor Green

# =============================================================================
# 2. Get AKS Credentials
# =============================================================================
Write-Host ""
Write-Host "=== 2/6 Getting AKS credentials ===" -ForegroundColor Yellow

az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get AKS credentials. Check resource group and cluster name." -ForegroundColor Red
    exit 1
}
Write-Host "✅ AKS credentials configured" -ForegroundColor Green

# =============================================================================
# 3. Setup Helm Repository
# =============================================================================
Write-Host ""
Write-Host "=== 3/6 Setting up Helm repository ===" -ForegroundColor Yellow

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null
helm repo update
Write-Host "✅ Helm repository configured" -ForegroundColor Green

# =============================================================================
# 4. Install NGINX Ingress Controller
# =============================================================================
Write-Host ""
Write-Host "=== 4/6 Installing NGINX Ingress Controller ===" -ForegroundColor Yellow

# Create namespace
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

Write-Host "Installing NGINX Ingress Helm chart version $ChartVersion..."

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
    --namespace $Namespace `
    --version $ChartVersion `
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
    Write-Host "ERROR: Helm installation failed." -ForegroundColor Red
    exit 1
}
Write-Host "✅ NGINX Ingress Controller installed successfully" -ForegroundColor Green

# =============================================================================
# 5. Wait for LoadBalancer IP
# =============================================================================
Write-Host ""
Write-Host "=== 5/6 Waiting for LoadBalancer IP ===" -ForegroundColor Yellow

$maxAttempts = 30
$attempt = 0
$ingressIP = $null

while ($attempt -lt $maxAttempts -and -not $ingressIP) {
    $attempt++
    $svc = kubectl get svc ingress-nginx-controller -n $Namespace -o json 2>$null | ConvertFrom-Json
    if ($svc -and $svc.status.loadBalancer.ingress) {
        $ingressIP = $svc.status.loadBalancer.ingress[0].ip
    }
    
    if (-not $ingressIP) {
        Write-Host "   Waiting for LoadBalancer IP... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

if ($ingressIP) {
    Write-Host "✅ LoadBalancer IP assigned: $ingressIP" -ForegroundColor Green
} else {
    Write-Host "⚠️  LoadBalancer IP not yet assigned. Check status later." -ForegroundColor Yellow
}

# =============================================================================
# 6. Verify Installation
# =============================================================================
Write-Host ""
Write-Host "=== 6/6 Verifying installation ===" -ForegroundColor Yellow

$pods = kubectl get pods -n $Namespace --no-headers 2>$null | Where-Object { $_ -match "Running" }
if ($pods) {
    Write-Host "✅ NGINX Ingress pods are running:" -ForegroundColor Green
    kubectl get pods -n $Namespace
} else {
    Write-Host "⚠️  No running pods found yet. They may still be starting." -ForegroundColor Yellow
}

# =============================================================================
# Output Results
# =============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  NGINX Ingress Controller Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

if ($ingressIP) {
    Write-Host "🌐 Ingress LoadBalancer IP: $ingressIP" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Create an Ingress resource to route traffic:" -ForegroundColor White
Write-Host @"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cloudgames-ingress
  namespace: cloudgames
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: api.cloudgames.com
    http:
      paths:
      - path: /users
        pathType: Prefix
        backend:
          service:
            name: user-api
            port:
              number: 80
      - path: /games
        pathType: Prefix
        backend:
          service:
            name: games-api
            port:
              number: 80
      - path: /payments
        pathType: Prefix
        backend:
          service:
            name: payments-api
            port:
              number: 80
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "2. Configure DNS:" -ForegroundColor White
Write-Host "   Point your domain to: $ingressIP" -ForegroundColor Gray
Write-Host ""
Write-Host "3. (Optional) Enable TLS/SSL with cert-manager:" -ForegroundColor White
Write-Host "   helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true" -ForegroundColor Gray
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  # Check NGINX Ingress status" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "  # Get LoadBalancer IP" -ForegroundColor Gray
Write-Host "  kubectl get svc ingress-nginx-controller -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "  # View NGINX logs" -ForegroundColor Gray
Write-Host "  kubectl logs -n $Namespace -l app.kubernetes.io/name=ingress-nginx --tail=50" -ForegroundColor White
Write-Host ""
Write-Host "  # List all Ingress resources" -ForegroundColor Gray
Write-Host "  kubectl get ingress --all-namespaces" -ForegroundColor White
Write-Host ""
Write-Host "💰 Cost Savings:" -ForegroundColor Cyan
Write-Host "   With NGINX Ingress: 1 LoadBalancer = ~$40/month" -ForegroundColor Green
Write-Host "   Without (3 services): 3 LoadBalancers = ~$120/month" -ForegroundColor Red
Write-Host "   Savings: ~$80/month (67% reduction)" -ForegroundColor Green
Write-Host ""
