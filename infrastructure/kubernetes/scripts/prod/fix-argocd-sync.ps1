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

# Helper function to sync app and wait (idempotent with retry)
function Sync-ArgoApp {
    param([string]$AppName, [int]$WaitSeconds = 60, [int]$MaxRetries = 2)
    
    # Check current status FIRST (idempotency check)
    $currentSync = kubectl get application $AppName -n argocd -o jsonpath='{.status.sync.status}' 2>$null
    $currentHealth = kubectl get application $AppName -n argocd -o jsonpath='{.status.health.status}' 2>$null
    
    # If already Synced and Healthy, skip
    if ($currentSync -eq "Synced" -and $currentHealth -eq "Healthy") {
        Write-Host "🔄 Syncing: $AppName..." -ForegroundColor $Colors.Info
        Write-Host "   ✅ Already Synced and Healthy (skipping)" -ForegroundColor $Colors.Success
        return $true
    }
    
    Write-Host "🔄 Syncing: $AppName..." -ForegroundColor $Colors.Info
    Write-Host "   Current status: $currentSync / $currentHealth" -ForegroundColor $Colors.Muted
    
    for ($retry = 1; $retry -le $MaxRetries; $retry++) {
        if ($retry -gt 1) {
            Write-Host "   🔄 Retry $retry/$MaxRetries..." -ForegroundColor $Colors.Warning
        }
        
        # Force sync
        kubectl patch application $AppName -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"prune":true}}}' --type merge 2>$null
        $syncResult = kubectl patch application $AppName -n argocd -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' --type merge 2>$null
        
        Write-Host "   ⏳ Waiting for sync (up to ${WaitSeconds}s)..." -ForegroundColor $Colors.Muted
        
        $elapsed = 0
        $success = $false
        
        while ($elapsed -lt $WaitSeconds) {
            $syncStatus = kubectl get application $AppName -n argocd -o jsonpath='{.status.sync.status}' 2>$null
            $health = kubectl get application $AppName -n argocd -o jsonpath='{.status.health.status}' 2>$null
            $opPhase = kubectl get application $AppName -n argocd -o jsonpath='{.status.operationState.phase}' 2>$null
            
            # Check if sync succeeded
            if ($opPhase -eq "Succeeded" -or ($syncStatus -eq "Synced" -and $health -ne "")) {
                Write-Host "   ✅ Synced successfully (Health: $health)" -ForegroundColor $Colors.Success
                $success = $true
                break
            } 
            
            # Check if sync failed
            if ($opPhase -eq "Failed") {
                Write-Host "   ❌ Sync operation failed" -ForegroundColor $Colors.Error
                
                # Get error message
                $errorMsg = kubectl get application $AppName -n argocd -o jsonpath='{.status.operationState.message}' 2>$null
                if ($errorMsg) {
                    Write-Host "      Error: $errorMsg" -ForegroundColor $Colors.Error
                }
                break
            }
            
            Start-Sleep -Seconds 3
            $elapsed += 3
        }
        
        if ($success) {
            return $true
        }
        
        if ($retry -lt $MaxRetries) {
            Write-Host "   ⏸️  Waiting 10s before retry..." -ForegroundColor $Colors.Muted
            Start-Sleep -Seconds 10
        }
    }
    
    Write-Host "   ⚠️  Sync incomplete after $MaxRetries attempts" -ForegroundColor $Colors.Warning
    return $false
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
    @{ Name = "azure-workload-identity"; Wait = 120 },
    @{ Name = "ingress-nginx"; Wait = 180 },
    @{ Name = "external-secrets-operator"; Wait = 120 }
)

foreach ($app in $apps) {
    $success = Sync-ArgoApp -AppName $app.Name -WaitSeconds $app.Wait -MaxRetries 2
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

$success = Sync-ArgoApp -AppName "cloudgames-prod" -WaitSeconds 180 -MaxRetries 3

if (-not $success) {
    Write-Host ""
    Write-Host "⚠️  cloudgames-prod sync incomplete - checking for specific issues..." -ForegroundColor $Colors.Warning
    
    # Check ClusterSecretStore status
    $cssStatus = kubectl get clustersecretstore azure-keyvault -o jsonpath='{.status.conditions[0].reason}' 2>$null
    if ($cssStatus -eq "InvalidProviderConfig") {
        Write-Host ""
        Write-Host "🔍 Detected ClusterSecretStore issue:" -ForegroundColor $Colors.Warning
        Write-Host "   The ESO cannot connect to Azure Key Vault" -ForegroundColor $Colors.Muted
        Write-Host "   This usually means Workload Identity is still propagating" -ForegroundColor $Colors.Muted
        Write-Host ""
        Write-Host "   Recommended actions:" -ForegroundColor $Colors.Info
        Write-Host "   1. Wait 2-3 minutes for Azure identity propagation" -ForegroundColor $Colors.Muted
        Write-Host "   2. Run: kubectl get externalsecrets -n cloudgames" -ForegroundColor $Colors.Muted
        Write-Host "   3. Re-run: .\aks-manager.ps1 fix-argocd-sync" -ForegroundColor $Colors.Muted
    }
    
    # Check for pod errors
    Write-Host ""
    Write-Host "   Checking pod status in cloudgames namespace..." -ForegroundColor $Colors.Muted
    $pods = kubectl get pods -n cloudgames --no-headers 2>$null
    if ($pods) {
        $pods | ForEach-Object {
            $parts = $_ -split '\s+'
            $podName = $parts[0]
            $status = $parts[2]
            
            if ($status -ne "Running") {
                Write-Host "      ⚠️  Pod $podName : $status" -ForegroundColor $Colors.Warning
            }
        }
    } else {
        Write-Host "      ℹ️  No pods found (may be creating)" -ForegroundColor $Colors.Muted
    }
}

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
