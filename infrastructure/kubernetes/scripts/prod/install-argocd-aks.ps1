<#
.SYNOPSIS
  Installs ArgoCD on Azure AKS cluster.
  
.DESCRIPTION
  This script installs ArgoCD on an Azure AKS cluster using Helm.
  It can be run locally (with az cli and kubectl configured) or 
  directly in Azure Cloud Shell.
  
  Features:
  - Installs ArgoCD via Helm with LoadBalancer service
  - Configures admin password
  - Waits for LoadBalancer IP assignment
  - Outputs access information
  
.PARAMETER ResourceGroup
  Azure Resource Group name containing the AKS cluster.
  
.PARAMETER ClusterName
  Name of the AKS cluster.
  
.PARAMETER AdminPassword
  ArgoCD admin password. Minimum 8 characters.
  Default: Argo@AKS123!
  
.PARAMETER Namespace
  Kubernetes namespace for ArgoCD.
  Default: argocd
  
.PARAMETER ChartVersion
  ArgoCD Helm chart version.
  Default: 7.7.16
  
.EXAMPLE
  # Run locally with default password
  .\install-argocd-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.EXAMPLE
  # Run locally with custom password
  .\install-argocd-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -AdminPassword "MySecurePass123!"
  
.EXAMPLE
  # Run in Azure Cloud Shell (copy & paste)
  # 1. Open Azure Cloud Shell (https://shell.azure.com)
  # 2. Switch to PowerShell
  # 3. Run:
  $RG = "tc-cloudgames-solution-dev-rg"
  $CLUSTER = "tc-cloudgames-dev-cr8n-aks"
  $PASSWORD = "Argo@AKS123!"
  
  az aks get-credentials --resource-group $RG --name $CLUSTER --overwrite-existing
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install argocd argo/argo-cd -n argocd --set server.service.type=LoadBalancer --set configs.params."server\.insecure"=true --set configs.secret.argocdServerAdminPassword=$(htpasswd -nbBC 10 "" $PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/')
  kubectl get svc argocd-server -n argocd -w

.NOTES
  Requirements:
  - Azure CLI (az) installed and logged in
  - kubectl installed
  - helm v3 installed
  
  For Azure Cloud Shell: All tools are pre-installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$AdminPassword = "Argo@AKS123!",
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "argocd",
    
    [Parameter(Mandatory = $false)]
    [string]$ChartVersion = "7.7.16",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# =============================================================================
# Configuration
# =============================================================================
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ArgoCD Installation for Azure AKS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Namespace      : $Namespace" -ForegroundColor White
Write-Host "Chart Version  : $ChartVersion" -ForegroundColor White
Write-Host ""

# =============================================================================
# 0. Check if ArgoCD already exists
# =============================================================================
$existingRelease = helm list -n $Namespace -q 2>$null | Where-Object { $_ -match "argocd" }
if ($existingRelease -and -not $Force) {
    Write-Host "⚠️  ArgoCD is already installed in namespace '$Namespace'" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to REINSTALL ArgoCD? This will DELETE and recreate it. (y/N)"
    
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "ℹ️  Installation cancelled. Existing ArgoCD installation preserved." -ForegroundColor Cyan
        exit 0
    }
    
    Write-Host ""
    Write-Host "🔄 Reinstalling ArgoCD..." -ForegroundColor Yellow
    
    # Call reset script for complete removal
    $resetScript = Join-Path $PSScriptRoot "reset-argocd-aks.ps1"
    if (Test-Path $resetScript) {
        & $resetScript -ResourceGroup $ResourceGroup -ClusterName $ClusterName -Force -SkipUninstall:$false
        Write-Host ""
        Write-Host "Continuing with fresh installation..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3
    }
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

Write-Host "Running: az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing"
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get AKS credentials. Check resource group and cluster name." -ForegroundColor Red
    exit 1
}
Write-Host "✅ AKS credentials configured" -ForegroundColor Green

# =============================================================================
# 3. Validate Cluster Connectivity
# =============================================================================
Write-Host ""
Write-Host "=== 3/6 Validating cluster connectivity ===" -ForegroundColor Yellow

$clusterInfo = kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Cannot connect to AKS cluster." -ForegroundColor Red
    Write-Host $clusterInfo
    exit 1
}
Write-Host "✅ Cluster is accessible" -ForegroundColor Green

# =============================================================================
# 4. Setup Helm Repository
# =============================================================================
Write-Host ""
Write-Host "=== 4/6 Setting up Helm repository ===" -ForegroundColor Yellow

helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo update
Write-Host "✅ Helm repository configured" -ForegroundColor Green

# =============================================================================
# 5. Install ArgoCD
# =============================================================================
Write-Host ""
Write-Host "=== 5/6 Installing ArgoCD ===" -ForegroundColor Yellow

# Create namespace
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Check if ArgoCD CRDs already exist (possibly from Terraform)
$existingCRDs = kubectl get crd applications.argoproj.io --ignore-not-found -o name 2>$null
if ($existingCRDs) {
    Write-Host "⚠️  ArgoCD CRDs already exist (possibly from Terraform). Adopting existing CRDs..." -ForegroundColor Yellow
    # Patch CRDs to be managed by Helm
    $crds = @(
        "applications.argoproj.io",
        "applicationsets.argoproj.io", 
        "appprojects.argoproj.io"
    )
    foreach ($crd in $crds) {
        kubectl annotate crd $crd meta.helm.sh/release-name=argocd --overwrite 2>$null
        kubectl annotate crd $crd meta.helm.sh/release-namespace=$Namespace --overwrite 2>$null
        kubectl label crd $crd app.kubernetes.io/managed-by=Helm --overwrite 2>$null
    }
    Write-Host "✅ CRDs annotated for Helm management" -ForegroundColor Green
}

# Generate bcrypt hash for password
# Note: ArgoCD expects bcrypt hash. We'll set the password after installation.
Write-Host "Installing ArgoCD Helm chart version $ChartVersion..."

helm upgrade --install argocd argo/argo-cd `
    --namespace $Namespace `
    --version $ChartVersion `
    --set server.service.type=LoadBalancer `
    --set "server.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path=/healthz" `
    --set server.ingress.enabled=false `
    --set configs.params."server\.insecure"=true `
    --set controller.resources.limits.cpu=500m `
    --set controller.resources.limits.memory=512Mi `
    --set controller.resources.requests.cpu=250m `
    --set controller.resources.requests.memory=256Mi `
    --set server.resources.limits.cpu=500m `
    --set server.resources.limits.memory=512Mi `
    --set server.resources.requests.cpu=250m `
    --set server.resources.requests.memory=256Mi `
    --wait `
    --timeout 10m

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Helm installation failed." -ForegroundColor Red
    exit 1
}
Write-Host "✅ ArgoCD installed successfully" -ForegroundColor Green

# =============================================================================
# 6. Configure Admin Password
# =============================================================================
Write-Host ""
Write-Host "=== 6/6 Configuring admin password ===" -ForegroundColor Yellow

# Get current admin password (initial random password)
$initialPassword = kubectl -n $Namespace get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($initialPassword) {
    $initialPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($initialPassword))
    Write-Host "Initial admin password retrieved from secret" -ForegroundColor Gray
}

# Update password using argocd CLI if available, otherwise show instructions
if (Get-Command argocd -ErrorAction SilentlyContinue) {
    Write-Host "Waiting for ArgoCD server to be ready..."
    Start-Sleep -Seconds 10
    
    # Get LoadBalancer IP
    $maxAttempts = 30
    $attempt = 0
    $serverIP = $null
    
    while ($attempt -lt $maxAttempts -and -not $serverIP) {
        $attempt++
        $svc = kubectl get svc argocd-server -n $Namespace -o json | ConvertFrom-Json
        $serverIP = $svc.status.loadBalancer.ingress[0].ip
        
        if (-not $serverIP) {
            Write-Host "   Waiting for LoadBalancer IP... ($attempt/$maxAttempts)" -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    }
    
    if ($serverIP) {
        Write-Host "Updating admin password via argocd CLI..."
        argocd login $serverIP --username admin --password $initialPassword --insecure
        argocd account update-password --current-password $initialPassword --new-password $AdminPassword
        Write-Host "✅ Admin password updated" -ForegroundColor Green
    }
} else {
    Write-Host "ℹ️  ArgoCD CLI not found. Password will remain as initial value." -ForegroundColor Yellow
    Write-Host "   To change password, install argocd CLI and run:" -ForegroundColor Yellow
    Write-Host "   argocd account update-password" -ForegroundColor Yellow
}

# =============================================================================
# Wait for LoadBalancer IP
# =============================================================================
Write-Host ""
Write-Host "=== Waiting for LoadBalancer IP ===" -ForegroundColor Yellow

$maxAttempts = 30
$attempt = 0
$serverIP = $null

while ($attempt -lt $maxAttempts -and -not $serverIP) {
    $attempt++
    $svc = kubectl get svc argocd-server -n $Namespace -o json | ConvertFrom-Json
    $serverIP = $svc.status.loadBalancer.ingress[0].ip
    
    if (-not $serverIP) {
        Write-Host "   Waiting for LoadBalancer IP... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

# =============================================================================
# Output Results
# =============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ArgoCD Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

if ($serverIP) {
    Write-Host "ArgoCD Server URL: http://$serverIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Credentials:" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor White
    if ($initialPassword -and -not (Get-Command argocd -ErrorAction SilentlyContinue)) {
        Write-Host "  Password: $initialPassword (initial - change after first login)" -ForegroundColor White
    } else {
        Write-Host "  Password: $AdminPassword" -ForegroundColor White
    }
} else {
    Write-Host "⚠️  LoadBalancer IP not yet assigned." -ForegroundColor Yellow
    Write-Host "   Run this command to check status:" -ForegroundColor Yellow
    Write-Host "   kubectl get svc argocd-server -n $Namespace -w" -ForegroundColor White
    Write-Host ""
    Write-Host "Credentials:" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor White
    if ($initialPassword) {
        Write-Host "  Password: $initialPassword (initial)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  # Check pods status" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "  # Check service (LoadBalancer IP)" -ForegroundColor Gray
Write-Host "  kubectl get svc argocd-server -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "  # Port-forward (alternative to LoadBalancer)" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/argocd-server -n $Namespace 8080:80" -ForegroundColor White
Write-Host ""
Write-Host "  # Get initial admin password" -ForegroundColor Gray
Write-Host "  kubectl -n $Namespace get secret argocd-initial-admin-secret -o jsonpath=`"{.data.password}`" | base64 -d" -ForegroundColor White
Write-Host ""
