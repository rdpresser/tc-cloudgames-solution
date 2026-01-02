<#
.SYNOPSIS
  Check Helm chart versions for Argo CD managed applications.

.DESCRIPTION
  This script checks all Helm charts managed by Argo CD applications,
  compares current versions with the latest available versions,
  and suggests updates when newer versions are available.

.PARAMETER ShowAll
  Show all charts even if they are up-to-date.

.EXAMPLE
  .\check-helm-chart-versions.ps1

.EXAMPLE
  .\check-helm-chart-versions.ps1 -ShowAll
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ShowAll
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     📊 Helm Chart Version Checker (Argo CD Apps)          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
foreach ($cmd in @("helm", "kubectl")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "❌ ERROR: '$cmd' is not installed or not on PATH." -ForegroundColor Red
        exit 1
    }
}

# =============================================================================
# Chart Definitions (from Argo CD Application manifests)
# =============================================================================
$charts = @(
    @{
        Name = "NGINX Ingress"
        Repo = "https://kubernetes.github.io/ingress-nginx"
        Chart = "ingress-nginx"
        CurrentVersion = "4.11.3"
        Manifest = "application-ingress-nginx.yaml"
    },
    @{
        Name = "External Secrets Operator"
        Repo = "https://charts.external-secrets.io"
        Chart = "external-secrets"
        CurrentVersion = "0.9.11"
        Manifest = "application-external-secrets.yaml"
    },
    @{
        Name = "Azure Workload Identity"
        Repo = "https://azure.github.io/azure-workload-identity/charts"
        Chart = "workload-identity-webhook"
        CurrentVersion = "1.1.0"
        Manifest = "application-azure-workload-identity.yaml"
    }
)

# =============================================================================
# Check Latest Versions
# =============================================================================
Write-Host "🔍 Checking latest versions from Helm repositories..." -ForegroundColor Yellow
Write-Host ""

$results = @()

foreach ($chart in $charts) {
    Write-Host "  📦 $($chart.Name)..." -NoNewline -ForegroundColor Gray
    
    try {
        # Add repo if not already present (silent)
        $repoName = $chart.Chart -replace "[^a-zA-Z0-9-]", ""
        helm repo add $repoName $chart.Repo 2>&1 | Out-Null
        
        # Update repo
        helm repo update $repoName 2>&1 | Out-Null
        
        # Search for latest version
        $searchResult = helm search repo "$repoName/$($chart.Chart)" --versions --output json | ConvertFrom-Json
        
        if ($searchResult) {
            $latestVersion = ($searchResult | Sort-Object -Property version -Descending | Select-Object -First 1).version
            
            $isUpToDate = $chart.CurrentVersion -eq $latestVersion
            $status = if ($isUpToDate) { "✅ UP-TO-DATE" } else { "⚠️  UPDATE AVAILABLE" }
            $statusColor = if ($isUpToDate) { "Green" } else { "Yellow" }
            
            Write-Host " $status" -ForegroundColor $statusColor
            
            $results += [PSCustomObject]@{
                Name = $chart.Name
                Chart = $chart.Chart
                CurrentVersion = $chart.CurrentVersion
                LatestVersion = $latestVersion
                IsUpToDate = $isUpToDate
                Manifest = $chart.Manifest
                Repo = $chart.Repo
            }
        }
        else {
            Write-Host " ❌ NOT FOUND" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " ❌ ERROR" -ForegroundColor Red
        Write-Host "     $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# =============================================================================
# Display Results
# =============================================================================
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📋 VERSION COMPARISON REPORT" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$hasUpdates = $false

foreach ($result in $results) {
    # Skip up-to-date charts if -ShowAll is not specified
    if (-not $ShowAll -and $result.IsUpToDate) {
        continue
    }
    
    $color = if ($result.IsUpToDate) { "Green" } else { "Yellow" }
    $badge = if ($result.IsUpToDate) { "✅" } else { "⚠️ " }
    
    Write-Host "$badge $($result.Name)" -ForegroundColor $color
    Write-Host "   Chart:           $($result.Chart)" -ForegroundColor Gray
    Write-Host "   Current Version: $($result.CurrentVersion)" -ForegroundColor $(if ($result.IsUpToDate) { "Gray" } else { "Yellow" })
    Write-Host "   Latest Version:  $($result.LatestVersion)" -ForegroundColor $(if ($result.IsUpToDate) { "Gray" } else { "Green" })
    Write-Host "   Manifest:        infrastructure/kubernetes/manifests/$($result.Manifest)" -ForegroundColor Gray
    
    if (-not $result.IsUpToDate) {
        $hasUpdates = $true
        Write-Host ""
        Write-Host "   📝 To update:" -ForegroundColor Cyan
        Write-Host "      1. Edit: infrastructure/kubernetes/manifests/$($result.Manifest)" -ForegroundColor White
        Write-Host "         Change targetRevision: $($result.CurrentVersion) → $($result.LatestVersion)" -ForegroundColor White
        Write-Host "      2. Commit and push changes" -ForegroundColor White
        Write-Host "      3. Argo CD will auto-sync the update" -ForegroundColor White
        Write-Host ""
        Write-Host "   Or use the update script:" -ForegroundColor Cyan
        Write-Host "      .\update-helm-chart-version.ps1 -Chart $($result.Chart) -Version $($result.LatestVersion)" -ForegroundColor White
    }
    
    Write-Host ""
}

# Show summary for up-to-date charts if -ShowAll
if ($ShowAll) {
    $upToDateCount = ($results | Where-Object { $_.IsUpToDate }).Count
    if ($upToDateCount -gt 0) {
        Write-Host "✅ $upToDateCount chart(s) are up-to-date" -ForegroundColor Green
        Write-Host ""
    }
}

# =============================================================================
# Summary
# =============================================================================
$totalCharts = $results.Count
$upToDate = ($results | Where-Object { $_.IsUpToDate }).Count
$needsUpdate = ($results | Where-Object { -not $_.IsUpToDate }).Count

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 📊 SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Charts:        $totalCharts" -ForegroundColor White
Write-Host "  Up-to-date:         $upToDate" -ForegroundColor Green
Write-Host "  Updates Available:  $needsUpdate" -ForegroundColor $(if ($needsUpdate -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

if ($needsUpdate -eq 0) {
    Write-Host "🎉 All Helm charts are up-to-date!" -ForegroundColor Green
}
else {
    Write-Host "⚠️  $needsUpdate chart(s) have updates available." -ForegroundColor Yellow
    Write-Host "   Review the updates above and apply them to your manifests." -ForegroundColor Yellow
}

Write-Host ""

# =============================================================================
# Additional Information
# =============================================================================
Write-Host "ℹ️  Additional Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Check current Argo CD applications" -ForegroundColor Gray
Write-Host "  kubectl get applications -n argocd" -ForegroundColor White
Write-Host ""
Write-Host "  # View chart details" -ForegroundColor Gray
Write-Host "  helm show chart <repo>/<chart> --version <version>" -ForegroundColor White
Write-Host ""
Write-Host "  # View all available versions" -ForegroundColor Gray
Write-Host "  helm search repo <chart> --versions" -ForegroundColor White
Write-Host ""
