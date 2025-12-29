<#
.SYNOPSIS
    Validates NGINX Ingress Controller installation (managed by ArgoCD).

.DESCRIPTION
    This script is DEPRECATED as an installer. NGINX should be installed via
    ArgoCD Helm Application (see infrastructure/kubernetes/manifests/application-ingress-nginx.yaml).
    It now only validates status and provides guidance.

.PARAMETER ResourceGroup
    Azure Resource Group name.

.PARAMETER ClusterName
    AKS cluster name.

.EXAMPLE
    .\install-nginx-ingress.ps1 -ResourceGroup "rg" -ClusterName "aks"
    # Validates ArgoCD-managed NGINX installation
#>

[CmdletBinding()]
param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,
    
        [Parameter(Mandatory = $true)]
        [string]$ClusterName
)

$ErrorActionPreference = "Stop"

Write-Host ""; Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  NGINX Ingress Controller - Validation & Guidance" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  DEPRECATION NOTICE:" -ForegroundColor Yellow
Write-Host "   This script no longer installs NGINX via Helm." -ForegroundColor Yellow
Write-Host "   NGINX is installed via ArgoCD Application 'ingress-nginx'." -ForegroundColor Yellow
Write-Host ""

Write-Host "Connecting to AKS cluster..." -ForegroundColor Cyan
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to get AKS credentials" -ForegroundColor Red; exit 1 }
Write-Host "✅ Connected to cluster: $ClusterName" -ForegroundColor Green

$appJson = kubectl get application ingress-nginx -n argocd -o json 2>$null
if ($LASTEXITCODE -eq 0 -and $appJson) {
        $app = $appJson | ConvertFrom-Json
        $health = $app.status.health.status
        $sync = $app.status.sync.status
        Write-Host "✅ ArgoCD Application 'ingress-nginx' found" -ForegroundColor Green
        Write-Host "   Health: $health" -ForegroundColor $(if ($health -eq "Healthy") { "Green" } else { "Yellow" })
        Write-Host "   Sync:   $sync" -ForegroundColor $(if ($sync -eq "Synced") { "Green" } else { "Yellow" })
        if ($health -ne "Healthy" -or $sync -ne "Synced") {
                Write-Host ""; Write-Host "⚠️  Application needs attention:" -ForegroundColor Yellow
                Write-Host "   argocd app sync ingress-nginx" -ForegroundColor Gray
        }
} else {
        Write-Host "❌ ArgoCD Application 'ingress-nginx' NOT found" -ForegroundColor Red
        Write-Host "   Apply it or ensure bootstrap picks it up:" -ForegroundColor Gray
        Write-Host "   kubectl apply -f infrastructure/kubernetes/manifests/application-ingress-nginx.yaml" -ForegroundColor Gray
        exit 1
}

$ns = "ingress-nginx"
$pods = kubectl get pods -n $ns --no-headers 2>$null
if ($pods) {
        $running = $pods | Where-Object { $_ -match "Running" }
        $rc = ($running | Measure-Object).Count
        $tc = ($pods | Measure-Object).Count
        Write-Host "✅ Pods running: $rc/$tc in namespace '$ns'" -ForegroundColor Green
        $ip = kubectl get svc ingress-nginx-controller -n $ns -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        if ($ip) { Write-Host "🌐 LoadBalancer IP: $ip" -ForegroundColor Cyan }
        Write-Host ""; kubectl get pods -n $ns; Write-Host ""; kubectl get svc -n $ns
} else {
        Write-Host "❌ No pods found in namespace '$ns'" -ForegroundColor Red
        Write-Host "   The ArgoCD Application may need to sync." -ForegroundColor Yellow
}

Write-Host ""
