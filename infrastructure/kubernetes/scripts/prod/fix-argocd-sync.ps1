<#
.SYNOPSIS
  Fix ArgoCD application sync order and webhook dependencies

.DESCRIPTION
  Ensures platform components are synced before cloudgames-prod
  Handles webhook validation errors that block application deployment

.EXAMPLE
  .\fix-argocd-sync.ps1
  # Forces sync of dependencies in correct order
#>

$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Muted   = "Gray"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Info
Write-Host "║   🔄 ArgoCD Application Sync Recovery                     ║" -ForegroundColor $Colors.Info
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Info
Write-Host ""

# Helper function to sync app and wait (idempotent)
function Sync-ArgoApp {
    param([string]$AppName, [int]$WaitSeconds = 60)
    
    # Check current status FIRST (idempotency check)
    $currentSync = kubectl get application $AppName -n argocd -o jsonpath='{.status.syncStatus}' 2>$null
    $currentHealth = kubectl get application $AppName -n argocd -o jsonpath='{.status.health.status}' 2>$null
    
    # If already Synced and Healthy, skip
    if ($currentSync -eq "Synced" -and $currentHealth -eq "Healthy") {
        Write-Host "🔄 Syncing: $AppName..." -ForegroundColor $Colors.Info
        Write-Host "   ✅ Already Synced and Healthy (skipping)" -ForegroundColor $Colors.Success
        return $true
    }
    
    Write-Host "🔄 Syncing: $AppName..." -ForegroundColor $Colors.Info
    Write-Host "   Current status: $currentSync / $currentHealth" -ForegroundColor $Colors.Muted
    
    # Force sync only if needed
    kubectl patch application $AppName -n argocd -p '{"spec":{"syncPolicy":{"syncOptions":["Refresh=hard"]}}}' --type merge 2>$null
    argocd app sync $AppName --force 2>$null
    
    Write-Host "   ⏳ Waiting for sync (up to ${WaitSeconds}s)..." -ForegroundColor $Colors.Muted
    
    $elapsed = 0
    while ($elapsed -lt $WaitSeconds) {
        $status = kubectl get application $AppName -n argocd -o jsonpath='{.status.operationState.phase}' 2>$null
        $health = kubectl get application $AppName -n argocd -o jsonpath='{.status.health.status}' 2>$null
        
        if ($status -eq "Succeeded" -and $health -ne "") {
            Write-Host "   ✅ Synced successfully" -ForegroundColor $Colors.Success
            return $true
        } elseif ($status -eq "Failed") {
            Write-Host "   ⚠️  Sync failed - will retry" -ForegroundColor $Colors.Warning
            return $false
        }
        
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
    
    Write-Host "   ⚠️  Sync still in progress (may continue in background)" -ForegroundColor $Colors.Warning
    return $true
}

# Step 1: Check prerequisites
Write-Host "Step 1/4: Checking prerequisites..." -ForegroundColor $Colors.Info
Write-Host ""

$kubectlOk = kubectl cluster-info 2>$null
if (-not $kubectlOk) {
    Write-Host "❌ kubectl not connected" -ForegroundColor $Colors.Error
    exit 1
}
Write-Host "✅ kubectl connected" -ForegroundColor $Colors.Success

# Check ArgoCD
$argocdCheck = kubectl get namespace argocd 2>$null
if (-not $argocdCheck) {
    Write-Host "❌ ArgoCD not found" -ForegroundColor $Colors.Error
    exit 1
}
Write-Host "✅ ArgoCD available" -ForegroundColor $Colors.Success
Write-Host ""

# Step 2: Sync platform dependencies first
Write-Host "Step 2/4: Syncing platform dependencies..." -ForegroundColor $Colors.Info
Write-Host ""

$apps = @(
    @{ Name = "azure-workload-identity"; Wait = 90 },
    @{ Name = "ingress-nginx"; Wait = 120 },
    @{ Name = "external-secrets-operator"; Wait = 90 }
)

foreach ($app in $apps) {
    Sync-ArgoApp -AppName $app.Name -WaitSeconds $app.Wait
    Write-Host ""
}

# Step 3: Verify webhooks are ready
Write-Host "Step 3/4: Verifying webhooks are ready..." -ForegroundColor $Colors.Info
Write-Host ""

$webhooks = @(
    "external-secrets-operator-webhook",
    "ingress-nginx-controller-admission",
    "azure-workload-identity-webhook"
)

foreach ($webhook in $webhooks) {
    Write-Host "  🔍 Checking: $webhook..." -ForegroundColor $Colors.Muted
    
    $endpointReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        $endpoints = kubectl get endpoints -A -o json 2>$null | ConvertFrom-Json
        $ready = $endpoints.items | Where-Object { $_.metadata.name -like "*$webhook*" -and $_.subsets.count -gt 0 }
        
        if ($ready) {
            Write-Host "     ✅ Ready" -ForegroundColor $Colors.Success
            $endpointReady = $true
            break
        }
        
        Start-Sleep -Seconds 1
    }
    
    if (-not $endpointReady) {
        Write-Host "     ⚠️  Not ready yet (may be deploying)" -ForegroundColor $Colors.Warning
    }
}
Write-Host ""

# Step 4: Sync cloudgames-prod
Write-Host "Step 4/4: Syncing cloudgames-prod application..." -ForegroundColor $Colors.Info
Write-Host ""

Sync-ArgoApp -AppName "cloudgames-prod" -WaitSeconds 120

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Success
Write-Host "║   ✅ Sync Recovery Complete                              ║" -ForegroundColor $Colors.Success
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Success
Write-Host ""

# Final status
Write-Host "📊 Final Status:" -ForegroundColor $Colors.Info
Write-Host ""

$allApps = kubectl get applications -n argocd --no-headers 2>$null
$allApps | ForEach-Object {
    $parts = $_ -split '\s+'
    $name = $parts[0]
    $syncStatus = $parts[1]
    $health = $parts[2]
    
    $statusColor = if ($syncStatus -eq "Synced") { $Colors.Success } else { $Colors.Warning }
    $healthColor = if ($health -eq "Healthy") { $Colors.Success } else { $Colors.Warning }
    
    Write-Host "  $name" -ForegroundColor $Colors.Muted
    Write-Host "    Sync:   $syncStatus" -ForegroundColor $statusColor
    Write-Host "    Health: $health" -ForegroundColor $healthColor
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor $Colors.Info
Write-Host "  1. Monitor progress: kubectl get app -n argocd -w" -ForegroundColor $Colors.Muted
Write-Host "  2. Check logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f" -ForegroundColor $Colors.Muted
Write-Host "  3. Access ArgoCD: .\aks-manager.ps1 get-argocd-url" -ForegroundColor $Colors.Muted
Write-Host ""
