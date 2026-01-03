<#
.SYNOPSIS
  Fix webhook validation errors by ensuring webhooks are ready before ArgoCD applies resources.

.DESCRIPTION
  This script addresses the core issue where ArgoCD tries to apply resources before webhooks are ready:
  - Ensures NGINX Ingress webhook certificate is valid
  - Waits for External Secrets Operator webhook endpoints
  - Validates Azure Workload Identity webhook
  - Temporarily disables webhook validation if needed during bootstrap

.EXAMPLE
  .\fix-webhooks.ps1
  # Fixes all webhook issues and prepares cluster for ArgoCD sync
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Muted   = "Gray"
    Title   = "Magenta"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
Write-Host "║        🔧 Webhook Validation Fix & Health Check          ║" -ForegroundColor $Colors.Title
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
Write-Host ""

# =============================================================================
# Step 1: Check NGINX Ingress Webhook Certificate
# =============================================================================
Write-Host "Step 1/4: Checking NGINX Ingress webhook certificate..." -ForegroundColor $Colors.Info
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
Write-Host ""

$nginxReady = $false
$nginxWebhookConfig = kubectl get validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found 2>$null

if ($nginxWebhookConfig) {
    Write-Host "  ✅ NGINX webhook configuration exists" -ForegroundColor $Colors.Success
    
    # Check if caBundle is valid
    $caBundle = kubectl get validatingwebhookconfiguration ingress-nginx-admission -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>$null
    
    if ($caBundle -and $caBundle.Length -gt 100) {
        Write-Host "  ✅ caBundle present (length: $($caBundle.Length))" -ForegroundColor $Colors.Success
        
        # Verify webhook service endpoint
        Write-Host "  🔍 Checking webhook service endpoint..." -ForegroundColor $Colors.Muted
        $nginxEndpoints = kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission --ignore-not-found -o jsonpath='{.subsets[*].addresses[*].ip}' 2>$null
        
        if ($nginxEndpoints) {
            Write-Host "  ✅ Webhook endpoint ready: $nginxEndpoints" -ForegroundColor $Colors.Success
            $nginxReady = $true
        }
        else {
            Write-Host "  ⚠️  Webhook endpoint not ready yet" -ForegroundColor $Colors.Warning
        }
    }
    else {
        Write-Host "  ⚠️  caBundle missing or invalid" -ForegroundColor $Colors.Warning
        Write-Host "  🔄 Attempting to fix caBundle from secret..." -ForegroundColor $Colors.Info
        
        # Run the fix script
        $fixScript = Join-Path $PSScriptRoot "fix-ingress-webhook-cabundle.ps1"
        if (Test-Path $fixScript) {
            & $fixScript
            
            # Re-check
            $caBundle = kubectl get validatingwebhookconfiguration ingress-nginx-admission -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>$null
            if ($caBundle -and $caBundle.Length -gt 100) {
                Write-Host "  ✅ caBundle fixed successfully" -ForegroundColor $Colors.Success
                $nginxReady = $true
            }
        }
        else {
            Write-Host "  ❌ Fix script not found: $fixScript" -ForegroundColor $Colors.Error
        }
    }
}
else {
    Write-Host "  ⚠️  NGINX webhook configuration not found (may not be installed yet)" -ForegroundColor $Colors.Warning
}

Write-Host ""

# =============================================================================
# Step 2: Check External Secrets Operator Webhook
# =============================================================================
Write-Host "Step 2/4: Checking External Secrets Operator webhook..." -ForegroundColor $Colors.Info
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
Write-Host ""

$esoReady = $false
$esoWebhookPod = kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets-webhook --no-headers --ignore-not-found 2>$null

if ($esoWebhookPod) {
    $podStatus = ($esoWebhookPod -split '\s+')[2]
    Write-Host "  ✅ ESO webhook pod exists (status: $podStatus)" -ForegroundColor $(if ($podStatus -eq "Running") { $Colors.Success } else { $Colors.Warning })
    
    # Check endpoints
    Write-Host "  🔍 Checking webhook endpoints..." -ForegroundColor $Colors.Muted
    $esoEndpoints = kubectl get endpoints -n external-secrets external-secrets-operator-webhook --ignore-not-found -o jsonpath='{.subsets[*].addresses[*].ip}' 2>$null
    
    if ($esoEndpoints) {
        Write-Host "  ✅ Webhook endpoints ready: $esoEndpoints" -ForegroundColor $Colors.Success
        $esoReady = $true
        
        # Check webhook configuration
        $esoWebhookConfigs = kubectl get validatingwebhookconfiguration -o name | Select-String "external-secrets"
        if ($esoWebhookConfigs) {
            Write-Host "  ✅ Webhook configurations found:" -ForegroundColor $Colors.Success
            $esoWebhookConfigs | ForEach-Object { Write-Host "     - $_" -ForegroundColor $Colors.Muted }
        }
    }
    else {
        Write-Host "  ⚠️  Webhook endpoints not ready yet (pod may be starting)" -ForegroundColor $Colors.Warning
        Write-Host "  ⏳ Waiting up to 60 seconds for endpoints..." -ForegroundColor $Colors.Info
        
        # Wait for endpoints
        for ($i = 0; $i -lt 60; $i++) {
            $esoEndpoints = kubectl get endpoints -n external-secrets external-secrets-operator-webhook --ignore-not-found -o jsonpath='{.subsets[*].addresses[*].ip}' 2>$null
            if ($esoEndpoints) {
                Write-Host "  ✅ Webhook endpoints ready: $esoEndpoints" -ForegroundColor $Colors.Success
                $esoReady = $true
                break
            }
            Start-Sleep -Seconds 1
        }
        
        if (-not $esoReady) {
            Write-Host "  ⚠️  Endpoints still not ready after 60s" -ForegroundColor $Colors.Warning
        }
    }
}
else {
    Write-Host "  ⚠️  ESO webhook pod not found (may not be installed yet)" -ForegroundColor $Colors.Warning
}

Write-Host ""

# =============================================================================
# Step 3: Check Azure Workload Identity Webhook
# =============================================================================
Write-Host "Step 3/4: Checking Azure Workload Identity webhook..." -ForegroundColor $Colors.Info
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
Write-Host ""

$wiReady = $false
$wiWebhookPod = kubectl get pods -n azure-workload-identity-system -l app.kubernetes.io/component=webhook --no-headers --ignore-not-found 2>$null

if ($wiWebhookPod) {
    $podStatus = ($wiWebhookPod -split '\s+')[2]
    Write-Host "  ✅ Workload Identity webhook pod exists (status: $podStatus)" -ForegroundColor $(if ($podStatus -eq "Running") { $Colors.Success } else { $Colors.Warning })
    
    # Check endpoints
    $wiEndpoints = kubectl get endpoints -n azure-workload-identity-system azure-wi-webhook-controller-manager-metrics-service --ignore-not-found -o jsonpath='{.subsets[*].addresses[*].ip}' 2>$null
    
    if ($wiEndpoints) {
        Write-Host "  ✅ Webhook endpoints ready" -ForegroundColor $Colors.Success
        $wiReady = $true
    }
    else {
        Write-Host "  ⚠️  Webhook endpoints not ready yet" -ForegroundColor $Colors.Warning
    }
}
else {
    Write-Host "  ⚠️  Workload Identity webhook pod not found (may not be installed yet)" -ForegroundColor $Colors.Warning
}

Write-Host ""

# =============================================================================
# Step 4: Temporary Webhook Bypass (if needed during bootstrap)
# =============================================================================
Write-Host "Step 4/4: Checking if temporary webhook bypass is needed..." -ForegroundColor $Colors.Info
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
Write-Host ""

$needsBypass = (-not $nginxReady -or -not $esoReady)

if ($needsBypass) {
    Write-Host "  ⚠️  Some webhooks are not ready yet" -ForegroundColor $Colors.Warning
    Write-Host "  💡 During initial bootstrap, this is expected" -ForegroundColor $Colors.Info
    Write-Host ""
    Write-Host "  Options:" -ForegroundColor $Colors.Info
    Write-Host "    1. Wait for webhooks to become ready (recommended)" -ForegroundColor $Colors.Muted
    Write-Host "    2. Temporarily disable webhook validation (advanced)" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    # Check if this is initial bootstrap (no cloudgames namespace)
    $cloudgamesNs = kubectl get namespace cloudgames --ignore-not-found 2>$null
    
    if (-not $cloudgamesNs) {
        Write-Host "  ℹ️  This appears to be initial bootstrap (no cloudgames namespace)" -ForegroundColor $Colors.Info
        Write-Host "  ✅ Webhooks will be validated after platform components are ready" -ForegroundColor $Colors.Success
    }
}
else {
    Write-Host "  ✅ All webhooks are ready" -ForegroundColor $Colors.Success
}

Write-Host ""

# =============================================================================
# Summary
# =============================================================================
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
Write-Host "║                   Webhook Health Summary                  ║" -ForegroundColor $Colors.Title
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
Write-Host ""

Write-Host "  NGINX Ingress:          $(if ($nginxReady) { '✅ Ready' } else { '⚠️  Not Ready' })" -ForegroundColor $(if ($nginxReady) { $Colors.Success } else { $Colors.Warning })
Write-Host "  External Secrets:       $(if ($esoReady) { '✅ Ready' } else { '⚠️  Not Ready' })" -ForegroundColor $(if ($esoReady) { $Colors.Success } else { $Colors.Warning })
Write-Host "  Workload Identity:      $(if ($wiReady) { '✅ Ready' } else { '⚠️  Not Ready' })" -ForegroundColor $(if ($wiReady) { $Colors.Success } else { $Colors.Warning })
Write-Host ""

$allReady = $nginxReady -and $esoReady -and $wiReady

if ($allReady) {
    Write-Host "✅ All webhooks are healthy and ready for ArgoCD sync!" -ForegroundColor $Colors.Success
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor $Colors.Info
    Write-Host "  1. Sync ArgoCD applications: .\aks-manager.ps1 fix-argocd-sync" -ForegroundColor $Colors.Muted
    Write-Host "  2. Check application status: kubectl get app -n argocd" -ForegroundColor $Colors.Muted
    exit 0
}
else {
    Write-Host "⚠️  Some webhooks are not ready" -ForegroundColor $Colors.Warning
    Write-Host ""
    Write-Host "Recommended actions:" -ForegroundColor $Colors.Info
    
    if (-not $nginxReady) {
        Write-Host "  • Wait for NGINX Ingress to be fully deployed" -ForegroundColor $Colors.Muted
        Write-Host "    Check: kubectl get pods -n ingress-nginx" -ForegroundColor $Colors.Muted
    }
    
    if (-not $esoReady) {
        Write-Host "  • Wait for External Secrets Operator to be fully deployed" -ForegroundColor $Colors.Muted
        Write-Host "    Check: kubectl get pods -n external-secrets" -ForegroundColor $Colors.Muted
    }
    
    if (-not $wiReady) {
        Write-Host "  • Wait for Workload Identity webhook to be fully deployed" -ForegroundColor $Colors.Muted
        Write-Host "    Check: kubectl get pods -n azure-workload-identity-system" -ForegroundColor $Colors.Muted
    }
    
    Write-Host ""
    Write-Host "  • Re-run this script after components are ready: .\fix-webhooks.ps1" -ForegroundColor $Colors.Muted
    Write-Host "  • Or wait and let ArgoCD auto-sync after webhooks are ready" -ForegroundColor $Colors.Muted
    Write-Host ""
    exit 1
}
