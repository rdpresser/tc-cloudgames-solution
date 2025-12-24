#!/usr/bin/env pwsh
<#
.SYNOPSIS
Force ArgoCD Image Updater to check and update all images immediately

.DESCRIPTION
Triggers immediate reconciliation by annotating the ImageUpdater CR and ArgoCD Applications
#>

param(
    [string]$Namespace = "argocd"
)

Write-Host "🔄 Forcing Image Updater reconciliation..." -ForegroundColor Cyan

# Force ImageUpdater CR reconciliation
kubectl annotate imageupdater cloudgames-images `
    -n argocd `
    argocd-image-updater.argoproj.io/force-check="$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')" `
    --overwrite

# Force production application sync
Write-Host "  🔄 Syncing cloudgames-prod..." -ForegroundColor Yellow
kubectl annotate application cloudgames-prod `
    -n $Namespace `
    argocd-image-updater.argoproj.io/write-back-target="cloudgames-prod" `
    --overwrite

Write-Host "✅ Force reconciliation triggered. Check logs:" -ForegroundColor Green
Write-Host "   kubectl logs -n argocd-image-updater -l app.kubernetes.io/name=argocd-image-updater -f" -ForegroundColor Gray
