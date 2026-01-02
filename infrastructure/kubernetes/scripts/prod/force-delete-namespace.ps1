<#
.SYNOPSIS
  Force delete namespaces stuck in Terminating state

.DESCRIPTION
  This script removes finalizers from namespaces stuck in Terminating state
  and forces their deletion. Use only when normal deletion fails.

.PARAMETER Namespace
  Name of the namespace to force delete. If not provided, will list all terminating namespaces.

.EXAMPLE
  .\force-delete-namespace.ps1 argocd
  # Force deletes the argocd namespace

.EXAMPLE
  .\force-delete-namespace.ps1
  # Lists all terminating namespaces
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Namespace
)

$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Muted   = "Gray"
}

function Show-TerminatingNamespaces {
    Write-Host "`n📋 Namespaces in Terminating state:" -ForegroundColor $Colors.Info
    Write-Host ""
    
    $terminating = kubectl get namespaces --field-selector status.phase=Terminating --no-headers 2>$null
    
    if (-not $terminating) {
        Write-Host "✅ No namespaces stuck in Terminating state" -ForegroundColor $Colors.Success
        return $false
    }
    
    foreach ($line in $terminating) {
        $nsName = ($line -split '\s+')[0]
        Write-Host "  ⚠️  $nsName" -ForegroundColor $Colors.Warning
    }
    
    Write-Host ""
    return $true
}

function Force-DeleteNamespace {
    param([string]$ns)
    
    Write-Host "`n🗑️  Force deleting namespace: $ns" -ForegroundColor $Colors.Warning
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Warning
    Write-Host ""
    
    # Check if namespace exists
    $nsExists = kubectl get namespace $ns --no-headers 2>$null
    if (-not $nsExists) {
        Write-Host "✅ Namespace $ns does not exist" -ForegroundColor $Colors.Success
        return
    }
    
    $nsStatus = ($nsExists -split '\s+')[1]
    Write-Host "Current status: $nsStatus" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    # Step 1: DELETE WEBHOOKS FIRST (they block everything!)
    Write-Host "Step 1/5: Removing blocking webhooks..." -ForegroundColor $Colors.Info
    
    $webhooksToDelete = @(
        "externalsecret-validate",
        "secretstore-validate",
        "ingress-nginx-admission",
        "azure-wi-webhook-mutating-webhook-configuration",
        "eso-webhook"
    )
    
    foreach ($webhook in $webhooksToDelete) {
        try {
            kubectl delete validatingwebhookconfiguration $webhook --ignore-not-found 2>$null
            kubectl delete mutatingwebhookconfiguration $webhook --ignore-not-found 2>$null
        } catch {
            # Continue
        }
    }
    Write-Host "  ✅ Webhooks cleanup attempted" -ForegroundColor $Colors.Success
    Write-Host ""
    
    # Step 2: Force delete resources with finalizers
    Write-Host "Step 2/5: Force deleting resources in namespace..." -ForegroundColor $Colors.Info
    
    try {
        # Delete CRD instances with grace-period=0
        $crdResources = @(
            "externalsecrets",
            "secretstores",
            "clustersecretstores",
            "imageupdaters",
            "applications"
        )
        
        foreach ($resource in $crdResources) {
            Write-Host "  🗑️  Attempting to delete $resource..." -ForegroundColor $Colors.Warning
            
            # Use timeout wrapper to prevent hanging (30 second timeout)
            try {
                $job = Start-Job -ScriptBlock {
                    param($res, $namespace)
                    kubectl delete $res --all -n $namespace --grace-period=0 --force --timeout=5s 2>$null
                } -ArgumentList $resource, $ns
                
                # Wait max 15 seconds for the job
                $job | Wait-Job -Timeout 15 | Out-Null
                
                if ($job.State -eq "Running") {
                    Write-Host "    ⏱️  Timeout - stopping job (continuing)" -ForegroundColor $Colors.Muted
                    Stop-Job -Job $job -Force 2>$null
                    Remove-Job -Job $job -Force 2>$null
                } else {
                    Remove-Job -Job $job -Force 2>$null
                }
            } catch {
                Write-Host "    ⚠️  Error during deletion (continuing)" -ForegroundColor $Colors.Muted
            }
        }
        
        Write-Host "  ✅ CRD resources force deletion attempted" -ForegroundColor $Colors.Success
    } catch {
        Write-Host "  ⚠️  Error during resource deletion (continuing)" -ForegroundColor $Colors.Warning
    }
    Write-Host ""
    
    # Step 3: Remove namespace finalizers using EDIT
    Write-Host "Step 3/5: Removing namespace finalizers..." -ForegroundColor $Colors.Info
    
    try {
        # Method 1: kubectl patch with jsonpath
        Write-Host "  Attempting patch method..." -ForegroundColor $Colors.Muted
        
        $job = Start-Job -ScriptBlock {
            param($ns)
            kubectl patch namespace $ns --type merge -p '{"spec":{"finalizers":[]}}' 2>&1
        } -ArgumentList $ns
        
        $job | Wait-Job -Timeout 10 | Out-Null
        $patchResult = Receive-Job -Job $job 2>$null
        
        if ($job.State -eq "Running") {
            Stop-Job -Job $job -Force 2>$null
        }
        Remove-Job -Job $job -Force 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Patch succeeded" -ForegroundColor $Colors.Success
        } else {
            Write-Host "  ⚠️  Patch failed, trying direct API method..." -ForegroundColor $Colors.Warning
            
            # Method 2: Direct API call to remove finalizers
            Write-Host "  Attempting direct API edit..." -ForegroundColor $Colors.Muted
            
            try {
                # Get namespace as JSON
                $nsJson = kubectl get namespace $ns -o json 2>$null
                
                if ($nsJson) {
                    $nsObj = $nsJson | ConvertFrom-Json
                    
                    # Clear finalizers
                    $nsObj.spec | Add-Member -Name "finalizers" -Value @() -Force
                    
                    # Convert to JSON and save to temp file
                    $jsonPatch = $nsObj | ConvertTo-Json -Depth 20
                    $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
                    Set-Content -Path $tempFile -Value $jsonPatch
                    
                    # Use kubectl replace with temp file
                    kubectl replace -f $tempFile 2>$null
                    Remove-Item -Path $tempFile -Force 2>$null
                    
                    Write-Host "  ✅ Direct API edit attempted" -ForegroundColor $Colors.Success
                }
            } catch {
                Write-Host "  ⚠️  Direct API edit failed, continuing..." -ForegroundColor $Colors.Warning
            }
        }
    } catch {
        Write-Host "  ⚠️  Error removing finalizers (continuing)" -ForegroundColor $Colors.Warning
    }
    Write-Host ""
    
    # Step 4: Wait for namespace deletion
    Write-Host "Step 4/5: Waiting for namespace deletion (5s)..." -ForegroundColor $Colors.Info
    Start-Sleep -Seconds 5
    
    # Try aggressive force delete
    Write-Host "  🗑️  Attempting aggressive force delete..." -ForegroundColor $Colors.Warning
    kubectl delete namespace $ns --grace-period=0 --force 2>$null
    
    Start-Sleep -Seconds 3
    
    $nsStillExists = kubectl get namespace $ns --no-headers 2>$null
    if ($nsStillExists) {
        Write-Host "  ⚠️  Namespace still exists after deletion attempts" -ForegroundColor $Colors.Warning
        Write-Host ""
        
        # Step 5: Nuclear option - directly patch via kubectl edit
        Write-Host "Step 5/5: Applying nuclear option (direct API patch)..." -ForegroundColor $Colors.Warning
        
        try {
            # Get the namespace as JSON and strip all finalizers
            $nsJson = kubectl get namespace $ns -o json 2>$null
            
            if ($nsJson) {
                $nsObj = $nsJson | ConvertFrom-Json
                
                # Remove ALL finalizers
                $nsObj.spec.finalizers = @()
                $nsObj.metadata.finalizers = @()
                
                # Convert back to JSON
                $cleanJson = $nsObj | ConvertTo-Json -Depth 20 -Compress
                
                # Write to temp file and apply via kubectl
                $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
                Set-Content -Path $tempFile -Value $cleanJson
                
                Write-Host "  Applying cleaned namespace (finalizers removed)..." -ForegroundColor $Colors.Muted
                kubectl replace -f $tempFile 2>$null
                
                Start-Sleep -Seconds 2
                
                # Force delete again
                Write-Host "  Force deleting namespace..." -ForegroundColor $Colors.Muted
                kubectl delete namespace $ns --grace-period=0 --force 2>$null
                
                Remove-Item $tempFile -Force 2>$null
                
                Write-Host "  ✅ Applied nuclear option" -ForegroundColor $Colors.Success
            }
        } catch {
            Write-Host "  ⚠️  Nuclear option error (see manual commands below)" -ForegroundColor $Colors.Warning
        }
    } else {
        Write-Host "  ✅ Namespace deleted successfully!" -ForegroundColor $Colors.Success
    }
    
    Write-Host ""
    
    # Final check
    Start-Sleep -Seconds 2
    $finalCheck = kubectl get namespace $ns --no-headers 2>$null
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $(if ($finalCheck) { $Colors.Warning } else { $Colors.Success })
    
    if ($finalCheck) {
        Write-Host "⚠️  Namespace $ns still exists" -ForegroundColor $Colors.Warning
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Warning
        Write-Host ""
        Write-Host "Next options:" -ForegroundColor $Colors.Info
        Write-Host "  1. Check resources: kubectl get all -n $ns" -ForegroundColor $Colors.Muted
        Write-Host "  2. Check finalizers: kubectl get ns $ns -o json | grep finalizers" -ForegroundColor $Colors.Muted
        Write-Host "  3. Delete via Portal: Go to AKS Resource Group in Azure Portal" -ForegroundColor $Colors.Muted
        Write-Host "  4. Advanced: kubectl patch ns $ns -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge" -ForegroundColor $Colors.Muted
    } else {
        Write-Host "✅ Namespace $ns successfully deleted!" -ForegroundColor $Colors.Success
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Success
    }
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Info
Write-Host "║     🗑️  Force Delete Namespace Utility                     ║" -ForegroundColor $Colors.Info
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Info

if (-not $Namespace) {
    # List terminating namespaces
    $hasTerminating = Show-TerminatingNamespaces
    
    if ($hasTerminating) {
        Write-Host "Usage:" -ForegroundColor $Colors.Info
        Write-Host "  .\force-delete-namespace.ps1 <namespace-name>" -ForegroundColor $Colors.Muted
        Write-Host ""
        Write-Host "Example:" -ForegroundColor $Colors.Info
        Write-Host "  .\force-delete-namespace.ps1 argocd" -ForegroundColor $Colors.Muted
        Write-Host ""
    }
    
    exit 0
}

# Force delete specific namespace
Force-DeleteNamespace -ns $Namespace
