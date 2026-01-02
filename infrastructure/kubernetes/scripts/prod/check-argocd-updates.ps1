<#
.SYNOPSIS
  Checks for ArgoCD updates and shows available versions.
  
.DESCRIPTION
  Fetches the latest ArgoCD releases from GitHub and displays available versions.
  Helps you decide which version to use for install-argocd-aks.ps1
  
.PARAMETER Limit
  Number of releases to display. Default: 10
  
.EXAMPLE
  .\check-argocd-updates.ps1
  
.EXAMPLE
  .\check-argocd-updates.ps1 -Limit 20
  
.NOTES
  Requires internet connection to reach GitHub API
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Limit = 10
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        ArgoCD Available Versions                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Fetching latest releases from GitHub..." -ForegroundColor Gray

try {
    # Fetch releases from GitHub API
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/argoproj/argo-cd/releases" -ErrorAction Stop | Select-Object -First $Limit
    
    Write-Host "Available ArgoCD Versions:" -ForegroundColor White
    Write-Host "──────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    
    $count = 0
    foreach ($release in $releases) {
        $count++
        $version = $release.tag_name
        $date = $release.published_at -split "T" | Select-Object -First 1
        $prerelease = if ($release.prerelease) { "⚠️  PRE-RELEASE" } else { "✅ STABLE" }
        
        Write-Host "$count. $version" -ForegroundColor Cyan -NoNewline
        Write-Host " ($date) - $prerelease" -ForegroundColor Gray
        
        if ($release.body.Length -gt 100) {
            $summary = $release.body.Substring(0, 100).Replace("`n", " ") -replace '\*\*|##|\*|-', ''
            Write-Host "   → $summary..." -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "──────" -ForegroundColor DarkGray
    Write-Host "  For latest stable:  .\install-argocd-aks.ps1 -Version stable" -ForegroundColor Gray
    Write-Host "  For specific:       .\install-argocd-aks.ps1 -Version v2.11.7" -ForegroundColor Gray
    Write-Host "  For development:    .\install-argocd-aks.ps1 -Version latest" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "ℹ️  Recommendation: Use 'stable' for production" -ForegroundColor Green
    Write-Host ""
    
} catch {
    Write-Host "❌ Error fetching releases from GitHub" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "GitHub releases page: https://github.com/argoproj/argo-cd/releases" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
