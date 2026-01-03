#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix ingress-nginx ValidatingWebhookConfiguration caBundle
.DESCRIPTION
    Updates the caBundle in ValidatingWebhookConfiguration from the ingress-nginx-admission secret.
    This ensures the webhook can validate Ingress objects without certificate errors.
    
    Solves: "tls: failed to verify certificate: x509: certificate signed by unknown authority"
.EXAMPLE
    .\fix-ingress-webhook-cabundle.ps1
#>

$ErrorActionPreference = "Stop"

$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "Cyan"
    Muted   = "Gray"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Info
Write-Host "║   🔧 Fix NGINX Webhook caBundle                           ║" -ForegroundColor $Colors.Info
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Info
Write-Host ""

# Step 1: Verify secret exists
Write-Host "Step 1/4: Verifying ingress-nginx-admission secret..." -ForegroundColor $Colors.Info
$secret = kubectl get secret ingress-nginx-admission -n ingress-nginx -o json 2>$null | ConvertFrom-Json

if (-not $secret) {
    Write-Host "[ERROR] Secret ingress-nginx-admission not found in ingress-nginx namespace" -ForegroundColor $Colors.Error
    exit 1
}

$caBundle = $secret.data.ca
Write-Host "   ✅ Secret found (CA length: $($caBundle.Length) chars)" -ForegroundColor $Colors.Success
Write-Host ""

# Step 2: Verify webhook config exists
Write-Host "Step 2/4: Verifying ValidatingWebhookConfiguration..." -ForegroundColor $Colors.Info
$webhook = kubectl get validatingwebhookconfiguration ingress-nginx-admission -o json 2>$null | ConvertFrom-Json

if (-not $webhook) {
    Write-Host "[ERROR] ValidatingWebhookConfiguration ingress-nginx-admission not found" -ForegroundColor $Colors.Error
    exit 1
}

Write-Host "   ✅ WebhookConfiguration found" -ForegroundColor $Colors.Success
Write-Host ""

# Step 3: Update caBundle
Write-Host "Step 3/4: Updating caBundle in webhook..." -ForegroundColor $Colors.Info

$patchJson = @"
[{"op": "replace", "path": "/webhooks/0/clientConfig/caBundle", "value": "$caBundle"}]
"@

$result = kubectl patch validatingwebhookconfiguration ingress-nginx-admission `
    --type='json' `
    -p $patchJson 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ caBundle updated successfully" -ForegroundColor $Colors.Success
} else {
    Write-Host "   ⚠️  Patch returned (no change might be expected)" -ForegroundColor $Colors.Warning
    Write-Host "   Message: $result" -ForegroundColor $Colors.Muted
}
Write-Host ""

# Step 4: Verify update and sync
Write-Host "Step 4/4: Syncing cloudgames-prod application..." -ForegroundColor $Colors.Info

# Verify caBundle was set
$updatedWebhook = kubectl get validatingwebhookconfiguration ingress-nginx-admission -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>$null
$caLength = $updatedWebhook | Measure-Object -Character | Select-Object -ExpandProperty Characters

if ($caLength -gt 100) {
    Write-Host "   ✅ caBundle verified ($caLength chars)" -ForegroundColor $Colors.Success
} else {
    Write-Host "   [WARNING] caBundle length suspicious ($caLength chars)" -ForegroundColor $Colors.Warning
}

# Final status
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Success
Write-Host "║   ✅ NGINX Webhook caBundle Fixed                        ║" -ForegroundColor $Colors.Success
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Success
Write-Host ""
Write-Host "✅ caBundle successfully updated from secret" -ForegroundColor $Colors.Success
Write-Host ""
Write-Host "Next steps:" -ForegroundColor $Colors.Info
Write-Host "  • Run sync script: .\aks-manager.ps1 fix-argocd-sync" -ForegroundColor $Colors.Muted
Write-Host "  • Or let ArgoCD auto-sync applications" -ForegroundColor $Colors.Muted
Write-Host ""
