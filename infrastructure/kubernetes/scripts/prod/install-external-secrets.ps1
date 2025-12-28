<#
.SYNOPSIS
  Validates External Secrets Operator installation on AKS cluster.

.DESCRIPTION
  ⚠️  DEPRECATION NOTICE:
  This script is now DEPRECATED. External Secrets Operator should be installed
  via ArgoCD Application (application-external-secrets.yaml) for GitOps consistency.
  
  This script now only VALIDATES that ESO is installed and provides guidance.
  It will NOT perform installation via Helm anymore.

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER ClusterName
  AKS cluster name.

.PARAMETER Force
  (DEPRECATED) This parameter is no longer used.

.EXAMPLE
  .\install-external-secrets.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  # Validates ESO installation and provides guidance

.NOTES
  For installation, ensure the ArgoCD Application 'external-secrets-operator' is synced:
  kubectl get application external-secrets-operator -n argocd
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
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  External Secrets Operator - Validation & Guidance" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  DEPRECATION NOTICE:" -ForegroundColor Yellow
Write-Host "   This script no longer installs ESO via Helm." -ForegroundColor Yellow
Write-Host "   ESO should be installed via ArgoCD for GitOps consistency." -ForegroundColor Yellow
Write-Host ""

# =============================================================================
# Connect to AKS
# =============================================================================
Write-Host "Connecting to AKS cluster..." -ForegroundColor Cyan

az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get AKS credentials" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connected to cluster: $ClusterName" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Check ArgoCD Application
# =============================================================================
Write-Host "Checking ArgoCD Application for ESO..." -ForegroundColor Cyan

$argoApp = kubectl get application external-secrets-operator -n argocd -o json 2>$null
if ($LASTEXITCODE -eq 0 -and $argoApp) {
    $appData = $argoApp | ConvertFrom-Json
    $health = $appData.status.health.status
    $sync = $appData.status.sync.status
    
    Write-Host "✅ ArgoCD Application 'external-secrets-operator' found" -ForegroundColor Green
    Write-Host "   Health: $health" -ForegroundColor $(if ($health -eq "Healthy") { "Green" } else { "Yellow" })
    Write-Host "   Sync:   $sync" -ForegroundColor $(if ($sync -eq "Synced") { "Green" } else { "Yellow" })
    
    if ($health -ne "Healthy" -or $sync -ne "Synced") {
        Write-Host ""
        Write-Host "⚠️  Application needs attention:" -ForegroundColor Yellow
        Write-Host "   kubectl get application external-secrets-operator -n argocd" -ForegroundColor Gray
        Write-Host "   argocd app sync external-secrets-operator" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ ArgoCD Application 'external-secrets-operator' NOT found" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 To install ESO via ArgoCD:" -ForegroundColor Yellow
    Write-Host "   1. Ensure application-external-secrets.yaml is in manifests/" -ForegroundColor Gray
    Write-Host "   2. Apply it:" -ForegroundColor Gray
    Write-Host "      kubectl apply -f infrastructure/kubernetes/manifests/application-external-secrets.yaml" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Or commit and let bootstrap Application sync it automatically." -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host ""

# =============================================================================
# Check ESO Pods
# =============================================================================
Write-Host "Checking ESO pods..." -ForegroundColor Cyan

$namespace = "external-secrets"
$esoPods = kubectl get pods -n $namespace --no-headers 2>$null

if ($esoPods) {
    $runningPods = $esoPods | Where-Object { $_ -match "Running" }
    $totalPods = ($esoPods | Measure-Object).Count
    $runningCount = ($runningPods | Measure-Object).Count
    
    Write-Host "✅ Found $runningCount/$totalPods pods running in namespace '$namespace'" -ForegroundColor Green
    Write-Host ""
    kubectl get pods -n $namespace
} else {
    Write-Host "❌ No pods found in namespace '$namespace'" -ForegroundColor Red
    Write-Host "   The ArgoCD Application may need to sync." -ForegroundColor Yellow
}

Write-Host ""

# =============================================================================
# Check CRDs
# =============================================================================
Write-Host "Checking External Secrets CRDs..." -ForegroundColor Cyan

$crds = kubectl get crds 2>$null | Select-String "external-secrets"
if ($crds) {
    Write-Host "✅ External Secrets CRDs installed:" -ForegroundColor Green
    $crds | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ External Secrets CRDs not found" -ForegroundColor Red
}

Write-Host ""

# =============================================================================
# Summary
# =============================================================================
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Validation Complete" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure Workload Identity for ESO:" -ForegroundColor Gray
Write-Host "     .\aks-manager.ps1 setup-eso-wi" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Verify ClusterSecretStore (applied via overlays):" -ForegroundColor Gray
Write-Host "     kubectl get clustersecretstore azure-keyvault" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Check ExternalSecrets in application namespaces:" -ForegroundColor Gray
Write-Host "     kubectl get externalsecrets -A" -ForegroundColor Gray
Write-Host ""
