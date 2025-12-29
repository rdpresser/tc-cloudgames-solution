<#
.SYNOPSIS
  Update Helm chart version in Argo CD Application manifest.

.DESCRIPTION
  This script updates the targetRevision field in an Argo CD Application
  manifest to a new Helm chart version.

.PARAMETER Chart
  Chart name (e.g., "ingress-nginx", "external-secrets", "workload-identity-webhook").

.PARAMETER Version
  Target chart version (e.g., "4.12.0").

.PARAMETER DryRun
  Show what would be changed without actually modifying files.

.EXAMPLE
  .\update-helm-chart-version.ps1 -Chart ingress-nginx -Version 4.12.0

.EXAMPLE
  .\update-helm-chart-version.ps1 -Chart external-secrets -Version 0.10.0 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("ingress-nginx", "external-secrets", "workload-identity-webhook")]
    [string]$Chart,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       📝 Helm Chart Version Updater (Argo CD Apps)        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Chart to Manifest Mapping
# =============================================================================
$chartManifests = @{
    "ingress-nginx" = @{
        File = "application-ingress-nginx.yaml"
        Name = "NGINX Ingress"
    }
    "external-secrets" = @{
        File = "application-external-secrets.yaml"
        Name = "External Secrets Operator"
    }
    "workload-identity-webhook" = @{
        File = "application-azure-workload-identity.yaml"
        Name = "Azure Workload Identity"
    }
}

$manifestInfo = $chartManifests[$Chart]
if (-not $manifestInfo) {
    Write-Host "❌ ERROR: Unknown chart '$Chart'" -ForegroundColor Red
    exit 1
}

$manifestPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "manifests" $manifestInfo.File

if (-not (Test-Path $manifestPath)) {
    Write-Host "❌ ERROR: Manifest file not found: $manifestPath" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Chart:    $($manifestInfo.Name)" -ForegroundColor White
Write-Host "📄 Manifest: $($manifestInfo.File)" -ForegroundColor White
Write-Host "🎯 Version:  $Version" -ForegroundColor White
Write-Host ""

# =============================================================================
# Validate Version Format
# =============================================================================
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "⚠️  WARNING: Version format should be semantic (e.g., 1.2.3)" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "❌ Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# =============================================================================
# Check if version exists in Helm repo
# =============================================================================
Write-Host "🔍 Verifying version exists in Helm repository..." -ForegroundColor Yellow

$repoName = $Chart -replace "[^a-zA-Z0-9-]", ""
$repoUrls = @{
    "ingress-nginx" = "https://kubernetes.github.io/ingress-nginx"
    "external-secrets" = "https://charts.external-secrets.io"
    "workload-identity-webhook" = "https://azure.github.io/azure-workload-identity/charts"
}

try {
    helm repo add $repoName $repoUrls[$Chart] 2>&1 | Out-Null
    helm repo update $repoName 2>&1 | Out-Null
    
    $versions = helm search repo "$repoName/$Chart" --versions --output json | ConvertFrom-Json
    $versionExists = $versions | Where-Object { $_.version -eq $Version }
    
    if (-not $versionExists) {
        Write-Host "❌ ERROR: Version $Version not found in repository" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available versions (latest 10):" -ForegroundColor Yellow
        $versions | Select-Object -First 10 | ForEach-Object {
            Write-Host "  - $($_.version)" -ForegroundColor Gray
        }
        Write-Host ""
        exit 1
    }
    
    Write-Host "✅ Version $Version exists in repository" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  WARNING: Could not verify version in repository" -ForegroundColor Yellow
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""

# =============================================================================
# Read Current Manifest
# =============================================================================
$content = Get-Content $manifestPath -Raw
$lines = Get-Content $manifestPath

# Find current version
$currentVersion = $null
$targetRevisionLine = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*targetRevision:\s*(.+)$') {
        $currentVersion = $matches[1].Trim()
        $targetRevisionLine = $i
        break
    }
}

if (-not $currentVersion) {
    Write-Host "❌ ERROR: Could not find 'targetRevision' in manifest" -ForegroundColor Red
    exit 1
}

Write-Host "📌 Current Version: $currentVersion" -ForegroundColor Yellow
Write-Host "🎯 Target Version:  $Version" -ForegroundColor Green
Write-Host ""

if ($currentVersion -eq $Version) {
    Write-Host "ℹ️  Chart is already at version $Version" -ForegroundColor Cyan
    exit 0
}

# =============================================================================
# Update Manifest
# =============================================================================
if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Would update line $($targetRevisionLine + 1):" -ForegroundColor Yellow
    Write-Host "  OLD: $($lines[$targetRevisionLine])" -ForegroundColor Red
    Write-Host "  NEW:     targetRevision: $Version" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Confirm update
Write-Host "⚠️  This will update the Argo CD Application manifest." -ForegroundColor Yellow
Write-Host ""
$response = Read-Host "Continue with update? (Y/n)"
if ($response -eq "n" -or $response -eq "N") {
    Write-Host "❌ Cancelled" -ForegroundColor Yellow
    exit 0
}

# Update content using safe string replacement instead of regex with backreferences
$searchPattern = "targetRevision: $currentVersion"
$replacePattern = "targetRevision: $Version"
$updatedContent = $content.Replace($searchPattern, $replacePattern)

# Write back to file
Set-Content -Path $manifestPath -Value $updatedContent -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "✅ Successfully updated manifest!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Review changes: git diff $($manifestInfo.File)" -ForegroundColor White
Write-Host "   2. Test in staging if available" -ForegroundColor White
Write-Host "   3. Commit: git add $($manifestInfo.File) && git commit -m 'chore: update $Chart to $Version'" -ForegroundColor White
Write-Host "   4. Push: git push" -ForegroundColor White
Write-Host "   5. Argo CD will auto-sync the update" -ForegroundColor White
Write-Host ""
Write-Host "🔍 Monitor the update:" -ForegroundColor Cyan
Write-Host "   kubectl get application -n argocd" -ForegroundColor White
Write-Host "   kubectl describe application <app-name> -n argocd" -ForegroundColor White
Write-Host ""
