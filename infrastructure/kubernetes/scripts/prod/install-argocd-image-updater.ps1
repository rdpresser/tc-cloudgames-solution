#Requires -Version 7.0
<#
.SYNOPSIS
Installs and configures ArgoCD Image Updater for automatic ACR image updates.

.DESCRIPTION
Configures ArgoCD Image Updater with:
- Helm installation with correct registries.conf
- Docker registry secret for ACR authentication
- ImageUpdater CRD for automatic image monitoring
- 'newest-build' strategy to compare digests by timestamp

.PARAMETER AcrUrl
ACR URL (default: tccloudgamesdevcr8nacr.azurecr.io)

.PARAMETER AcrPassword
ACR password. Obtain via:
  az acr credential show -n <registry-name> -g <resource-group> --query "passwords[0].value" -o tsv

.EXAMPLE
.\install-argocd-image-updater.ps1 -AcrPassword "..."

.NOTES
Dependencies: kubectl, helm, curl
#>

param(
    [string]$AcrUrl = "tccloudgamesdevcr8nacr.azurecr.io",
    [string]$AcrUsername = "00000000-0000-0000-0000-000000000000",
    [string]$AcrPassword = $env:ACR_PASSWORD
)

$ErrorActionPreference = "Stop"

# ===== FUNCTIONS =====
function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $colors = @{'Success' = 'Green'; 'Error' = 'Red'; 'Warning' = 'Yellow'; 'Info' = 'Cyan'}
    $color = $colors[$Type] ?? 'White'
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

# ===== VALIDATIONS =====
Write-Status "=== Validating Dependencies ===" 'Info'

$cmds = @("kubectl", "helm")
foreach ($cmd in $cmds) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Status "Command not found: $cmd" 'Error'
        exit 1
    }
}

if ([string]::IsNullOrEmpty($AcrPassword)) {
    Write-Status "ACR_PASSWORD not provided" 'Error'
    exit 1
}

# ===== CREATE NAMESPACE =====
Write-Status "Creating namespace argocd-image-updater..." 'Info'
kubectl create namespace argocd-image-updater --dry-run=client -o yaml | kubectl apply -f -

# ===== CREATE DOCKER REGISTRY SECRET =====
Write-Status "Creating docker registry secret for ACR..." 'Info'
kubectl create secret docker-registry argocd-image-updater-docker-config `
    --docker-server=$AcrUrl `
    --docker-username=$AcrUsername `
    --docker-password=$AcrPassword `
    --docker-email="ci@cloudgames.local" `
    --namespace=argocd-image-updater `
    --dry-run=client -o yaml | kubectl apply -f -

Write-Status "Secret created: argocd-image-updater-docker-config" 'Success'

# ===== INSTALL VIA HELM =====
Write-Status "Adding ArgoCD Helm repo..." 'Info'
helm repo add argo https://argoproj.github.io/argo-helm 2>&1 | Out-Null
helm repo update argo 2>&1 | Out-Null

Write-Status "Installing ArgoCD Image Updater via Helm..." 'Info'
helm upgrade --install argocd-image-updater argo/argocd-image-updater `
    --namespace argocd-image-updater `
    --set "serviceAccount.create=true" `
    --set "serviceAccount.name=argocd-image-updater" `
    --set "config.logLevel=debug" `
    --set "podSecurityContext.fsGroup=65534" `
    --wait `
    --timeout 5m 2>&1 | Out-Null

Write-Status "Waiting for pod to be ready..." 'Info'
kubectl rollout status deployment/argocd-image-updater-controller `
    -n argocd-image-updater --timeout=5m 2>&1 | Out-Null

# ===== UPDATE CONFIGMAP WITHOUT SECRET REFERENCE =====
Write-Status "Updating ConfigMap registries.conf (without pullSecret)..." 'Info'

$registriesConf = @"
registries:
  - api_url: https://$AcrUrl
    insecure: false
    name: $AcrUrl
    ping: true
    prefix: $AcrUrl
"@

# Patch the ConfigMap
kubectl patch configmap argocd-image-updater-config `
    -n argocd-image-updater `
    --type merge `
    -p @{data=@{"registries.conf"=$registriesConf}} 2>&1 | Out-Null

Write-Status "ConfigMap updated (credentials removed to use docker-config)" 'Success'
# ===== MOUNT SECRET AS VOLUME =====
Write-Status "Configuring secret volume mount..." 'Info'

# Create a ConfigMap to be mounted as home/.docker/config.json
$dockerConfigSecret = kubectl get secret argocd-image-updater-docker-config `
    -n argocd-image-updater -o jsonpath='{.data.\.[dockerconfig]}' 2>&1

# Create deployment patch to mount secret
$deploymentPatch = @{
    spec = @{
        template = @{
            spec = @{
                volumes = @(
                    @{
                        name = "docker-config"
                        secret = @{
                            secretName = "argocd-image-updater-docker-config"
                            items = @(
                                @{
                                    key = ".dockerconfig"
                                    path = "config.json"
                                }
                            )
                            defaultMode = 256  # 0400 octal = 256 decimal
                        }
                    }
                )
                containers = @(
                    @{
                        name = "argocd-image-updater"
                        volumeMounts = @(
                            @{
                                name = "docker-config"
                                mountPath = "/home/argocd/.docker"
                                readOnly = $true
                            }
                        )
                        env = @(
                            @{
                                name = "DOCKER_CONFIG"
                                value = "/home/argocd/.docker"
                            },
                            @{
                                name = "HOME"
                                value = "/home/argocd"
                            }
                        )
                    }
                )
            }
        }
    }
} | ConvertTo-Json -Depth 10

kubectl patch deployment argocd-image-updater-controller `
    -n argocd-image-updater `
    --type merge `
    -p $deploymentPatch 2>&1 | Out-Null

Write-Status "Volume mount configured" 'Success'
# ===== APPLY IMAGEUPDATER CRD =====
Write-Status "Applying ImageUpdater CRD..." 'Info'

$crdPath = "$(Split-Path $PSScriptRoot -Parent)/../base/image-updater-cr.yaml"
if (Test-Path $crdPath) {
    kubectl apply -f $crdPath 2>&1 | Out-Null
    Write-Status "ImageUpdater CRD applied with 'newest-build' strategy" 'Success'
} else {
    Write-Status "CRD file not found: $crdPath" 'Warning'
}

# ===== RESTART CONTROLLER =====
Write-Status "Restarting controller to load new configurations..." 'Info'
kubectl rollout restart deployment argocd-image-updater-controller `
    -n argocd-image-updater 2>&1 | Out-Null

kubectl rollout status deployment/argocd-image-updater-controller `
    -n argocd-image-updater --timeout=3m 2>&1 | Out-Null

# ===== FINAL VALIDATIONS =====
Write-Status "=== Final Validations ===" 'Info'

$podStatus = kubectl get pod -n argocd-image-updater `
    -l app.kubernetes.io/name=argocd-image-updater `
    -o jsonpath='{.items[0].status.phase}' 2>&1

if ($podStatus -eq "Running") {
    Write-Status "✓ Pod running: $podStatus" 'Success'
} else {
    Write-Status "Pod status: $podStatus" 'Warning'
}

$crCount = kubectl get imageupdater -n argocd -o jsonpath='{.items | length}' 2>&1
Write-Status "ImageUpdater CRs found: $crCount" 'Info'

# ===== SUMMARY =====
Write-Status "" 'Info'
Write-Status "=== ✓ INSTALLATION COMPLETED ===" 'Success'
Write-Status "" 'Info'
Write-Status "Configuration:" 'Info'
Write-Status "  ACR: $AcrUrl" 'Info'
Write-Status "  Namespace: argocd-image-updater" 'Info'
Write-Status "  Strategy: newest-build (compares digest timestamps)" 'Info'
Write-Status "" 'Info'
Write-Status "Next steps:" 'Info'
Write-Status "1. Wait 2-3 minutes for first execution" 'Info'
Write-Status "2. Check logs: kubectl logs -n argocd-image-updater -f" 'Info'
Write-Status "3. Confirm CRD: kubectl get imageupdater -n argocd" 'Info'
Write-Status "4. Check ArgoCD for new digests" 'Info'
