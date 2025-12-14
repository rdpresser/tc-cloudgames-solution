<#
.SYNOPSIS
  Installs External Secrets Operator (ESO) on Azure AKS cluster.
  
.DESCRIPTION
  This script installs External Secrets Operator on an Azure AKS cluster using Helm.
  ESO synchronizes secrets from Azure Key Vault to Kubernetes secrets automatically.
  
  Features:
  - Installs ESO via Helm
  - Configures CRDs (ExternalSecret, SecretStore, ClusterSecretStore)
  - Prepares integration with Azure Key Vault via Managed Identity
  
.PARAMETER ResourceGroup
  Azure Resource Group name containing the AKS cluster.
  
.PARAMETER ClusterName
  Name of the AKS cluster.
  
.PARAMETER Namespace
  Kubernetes namespace for ESO.
  Default: external-secrets
  
.PARAMETER ChartVersion
  ESO Helm chart version.
  Default: 0.9.11
  
.PARAMETER Force
  Skip confirmation prompts and force reinstall if already exists.
  
.EXAMPLE
  .\install-external-secrets-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.NOTES
  Requirements:
  - Azure CLI (az) installed and logged in
  - kubectl installed
  - helm v3 installed
  - AKS cluster with Managed Identity enabled
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "external-secrets",
    
    [Parameter(Mandatory = $false)]
    [string]$ChartVersion = "0.9.11",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  External Secrets Operator Installation for Azure AKS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Namespace      : $Namespace" -ForegroundColor White
Write-Host "Chart Version  : $ChartVersion" -ForegroundColor White
Write-Host ""

# =============================================================================
# 0. Check if ESO already exists
# =============================================================================
$existingRelease = helm list -n $Namespace -q 2>$null | Where-Object { $_ -match "external-secrets" }
if ($existingRelease -and -not $Force) {
    Write-Host "⚠️  External Secrets Operator is already installed in namespace '$Namespace'" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to REINSTALL ESO? This will DELETE and recreate it. (y/N)"
    
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "ℹ️  Installation cancelled. Existing ESO installation preserved." -ForegroundColor Cyan
        exit 0
    }
    
    Write-Host ""
    Write-Host "🔄 Uninstalling existing ESO..." -ForegroundColor Yellow
    helm uninstall $existingRelease -n $Namespace --wait 2>$null
    kubectl delete namespace $Namespace --timeout=60s 2>$null
    Start-Sleep -Seconds 5
}

# =============================================================================
# 1. Check Prerequisites
# =============================================================================
Write-Host "=== 1/5 Checking prerequisites ===" -ForegroundColor Yellow

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
Write-Host "=== 2/5 Getting AKS credentials ===" -ForegroundColor Yellow

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
Write-Host "=== 3/5 Setting up Helm repository ===" -ForegroundColor Yellow

helm repo add external-secrets https://charts.external-secrets.io 2>$null
helm repo update
Write-Host "✅ Helm repository configured" -ForegroundColor Green

# =============================================================================
# 4. Install External Secrets Operator
# =============================================================================
Write-Host ""
Write-Host "=== 4/5 Installing External Secrets Operator ===" -ForegroundColor Yellow

# Create namespace
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

Write-Host "Installing ESO Helm chart version $ChartVersion..."

helm upgrade --install external-secrets external-secrets/external-secrets `
    --namespace $Namespace `
    --version $ChartVersion `
    --set installCRDs=true `
    --set webhook.port=9443 `
    --set resources.limits.cpu=200m `
    --set resources.limits.memory=256Mi `
    --set resources.requests.cpu=100m `
    --set resources.requests.memory=128Mi `
    --wait `
    --timeout 5m

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Helm installation failed." -ForegroundColor Red
    exit 1
}
Write-Host "✅ External Secrets Operator installed successfully" -ForegroundColor Green

# =============================================================================
# 5. Verify Installation
# =============================================================================
Write-Host ""
Write-Host "=== 5/5 Verifying installation ===" -ForegroundColor Yellow

Start-Sleep -Seconds 5

$pods = kubectl get pods -n $Namespace --no-headers 2>$null
if ($pods) {
    Write-Host "✅ ESO pods are running:" -ForegroundColor Green
    kubectl get pods -n $Namespace
} else {
    Write-Host "⚠️  No pods found yet. They may still be starting." -ForegroundColor Yellow
}

# Check CRDs
Write-Host ""
Write-Host "Checking installed CRDs..." -ForegroundColor Gray
$crds = kubectl get crd | Select-String "external-secrets.io"
if ($crds) {
    Write-Host "✅ ESO CRDs installed:" -ForegroundColor Green
    $crds | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
}

# =============================================================================
# Output Results
# =============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  External Secrets Operator Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Configure ClusterSecretStore to connect to Azure Key Vault:" -ForegroundColor White
Write-Host "   - Ensure AKS has Managed Identity enabled" -ForegroundColor Gray
Write-Host "   - Grant Key Vault access to the Managed Identity" -ForegroundColor Gray
Write-Host "   - Create a ClusterSecretStore manifest" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Example ClusterSecretStore:" -ForegroundColor White
Write-Host @"
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: https://your-keyvault.vault.azure.net/
      tenantId: your-tenant-id
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "3. Example ExternalSecret:" -ForegroundColor White
Write-Host @"
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: cloudgames
spec:
  secretStoreRef:
    name: azure-keyvault
    kind: ClusterSecretStore
  target:
    name: db-secret
  data:
  - secretKey: password
    remoteRef:
      key: database-password
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  # Check ESO status" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "  # View ESO logs" -ForegroundColor Gray
Write-Host "  kubectl logs -n $Namespace -l app.kubernetes.io/name=external-secrets" -ForegroundColor White
Write-Host ""
Write-Host "  # List ExternalSecrets" -ForegroundColor Gray
Write-Host "  kubectl get externalsecrets --all-namespaces" -ForegroundColor White
Write-Host ""
