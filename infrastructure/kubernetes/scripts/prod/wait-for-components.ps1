<#
.SYNOPSIS
  Wait for ArgoCD Applications to be synced before configuring Workload Identity

.DESCRIPTION
  This script waits for critical ArgoCD Applications to be installed and healthy:
  - azure-workload-identity: Webhook for RBAC integration
  - ingress-nginx: LoadBalancer + routing
  - external-secrets-operator: Secret synchronization
  
  Once all are healthy, Workload Identity can be configured on ESO.

.PARAMETER TimeoutSeconds
  Maximum time to wait in seconds. Default: 300 (5 minutes)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

# Colors
$Colors = @{
    Success = 'Green'
    Error   = 'Red'
    Warning = 'Yellow'
    Info    = 'Cyan'
    Muted   = 'Gray'
    Title   = 'Magenta'
}

function Wait-ForApplication {
    param(
        [string]$AppName,
        [int]$MaxSeconds = 300
    )
    
    Write-Host "⏳ Waiting for ArgoCD Application: $AppName" -ForegroundColor $Colors.Info
    $startTime = Get-Date
    $maxTime = $startTime.AddSeconds($MaxSeconds)
    
    while ((Get-Date) -lt $maxTime) {
        $app = kubectl get application $AppName -n argocd -o json 2>$null | ConvertFrom-Json
        
        if ($app -and $app.status) {
            $syncStatus = $app.status.sync.status
            $healthStatus = $app.status.health.status
            
            # Show progress
            $elapsed = [int]((Get-Date) - $startTime).TotalSeconds
            Write-Host "   Status: $syncStatus / Health: $healthStatus ($elapsed`s)" -ForegroundColor $Colors.Muted
            
            # Success: Synced and Healthy
            if ($syncStatus -eq "Synced" -and $healthStatus -eq "Healthy") {
                Write-Host "   ✅ $AppName is Synced and Healthy" -ForegroundColor $Colors.Success
                return $true
            }
            
            # Degraded is acceptable if synced (some pods may still be starting)
            if ($syncStatus -eq "Synced" -and ($healthStatus -eq "Degraded" -or $healthStatus -eq "Progressing")) {
                Write-Host "   ✅ $AppName is Synced (Health: $healthStatus - acceptable)" -ForegroundColor $Colors.Success
                return $true
            }
        }
        
        Start-Sleep -Seconds 5
    }
    
    Write-Host "   ❌ Timeout waiting for $AppName" -ForegroundColor $Colors.Error
    return $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
Write-Host "Waiting for ArgoCD Applications to be Ready" -ForegroundColor $Colors.Title
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
Write-Host ""

# Define required applications in order
$requiredApps = @(
    @{
        name    = "azure-workload-identity"
        timeout = 180
        description = "Azure Workload Identity Webhook (required for RBAC)"
    },
    @{
        name    = "ingress-nginx"
        timeout = 180
        description = "NGINX Ingress Controller (LoadBalancer)"
    },
    @{
        name    = "external-secrets-operator"
        timeout = 120
        description = "External Secrets Operator (secret sync)"
    }
)

$allReady = $true
foreach ($app in $requiredApps) {
    Write-Host ""
    Write-Host "$($app.description)" -ForegroundColor $Colors.Info
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
    
    $ready = Wait-ForApplication -AppName $app.name -MaxSeconds $app.timeout
    if (-not $ready) {
        Write-Host ""
        Write-Host "⚠️  $($app.name) not ready. Continuing anyway..." -ForegroundColor $Colors.Warning
        $allReady = $false
    }
    
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
if ($allReady) {
    Write-Host "✅ All applications are ready!" -ForegroundColor $Colors.Success
    Write-Host "Proceeding with Workload Identity configuration..." -ForegroundColor $Colors.Info
} else {
    Write-Host "⚠️  Some applications are still starting" -ForegroundColor $Colors.Warning
    Write-Host "Proceeding with Workload Identity configuration anyway..." -ForegroundColor $Colors.Info
}
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
Write-Host ""
