<#
.SYNOPSIS
  Install and configure ArgoCD Image Updater on AKS.

.DESCRIPTION
  This script installs ArgoCD Image Updater via Helm and configures it to
  automatically detect new images in Azure Container Registry (ACR) and
  update Kubernetes deployments.

.PARAMETER ResourceGroup
  Azure Resource Group name (e.g., tc-cloudgames-solution-dev-rg)

.PARAMETER ClusterName
  AKS cluster name (e.g., tc-cloudgames-dev-cr8n-aks)

.PARAMETER KeyVaultName
  Azure Key Vault name for ACR credentials

.PARAMETER ACRLoginServer
  ACR login server (e.g., tccloudgamesdevcr8nacr.azurecr.io)

.PARAMETER Force
  Force reinstall by uninstalling first

.EXAMPLE
  .\install-argocd-image-updater.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -KeyVaultName "tccloudgamesdevcr8nkv" -ACRLoginServer "tccloudgamesdevcr8nacr.azurecr.io"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$ACRLoginServer,

    [Parameter()]
    [switch]$Force
)

# Colors
$Colors = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "White"
    Muted   = "Gray"
}

function Write-InfoMessage {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Colors.Info
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Colors.Success
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Colors.Error
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Colors.Warning
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
Write-Host "║      📦 ArgoCD Image Updater Installation & Setup         ║" -ForegroundColor $Colors.Title
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
Write-Host ""

# =============================================================================
# 1. Check prerequisites
# =============================================================================
Write-InfoMessage "Checking prerequisites..."

$prerequisites = @("kubectl", "helm", "az")
foreach ($cmd in $prerequisites) {
    try {
        $null = & $cmd --version 2>&1
        Write-SuccessMessage "$cmd is installed"
    }
    catch {
        Write-ErrorMessage "$cmd is not installed"
        exit 1
    }
}

# =============================================================================
# 2. Check Kubernetes connectivity
# =============================================================================
Write-InfoMessage "Checking Kubernetes connectivity..."
try {
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-SuccessMessage "Connected to Kubernetes cluster"
    }
    else {
        Write-ErrorMessage "Cannot connect to Kubernetes cluster"
        exit 1
    }
}
catch {
    Write-ErrorMessage "Cannot connect to Kubernetes cluster: $_"
    exit 1
}

# =============================================================================
# 3. Check if ArgoCD Image Updater is already installed
# =============================================================================
Write-InfoMessage "Checking if ArgoCD Image Updater is already installed..."
$imageUpdaterNamespace = "argocd-image-updater"
$existingInstall = kubectl get namespace $imageUpdaterNamespace 2>$null

if ($existingInstall -and -not $Force) {
    Write-WarningMessage "ArgoCD Image Updater is already installed in namespace '$imageUpdaterNamespace'"
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-InfoMessage "Skipping installation"
        exit 0
    }
    $Force = $true
}

# =============================================================================
# 4. Force uninstall if requested
# =============================================================================
if ($Force -and $existingInstall) {
    Write-WarningMessage "Uninstalling existing ArgoCD Image Updater..."
    try {
        helm uninstall argocd-image-updater -n $imageUpdaterNamespace 2>$null
        kubectl delete namespace $imageUpdaterNamespace --ignore-not-found=true 2>$null
        Start-Sleep -Seconds 5
        Write-SuccessMessage "Uninstalled existing ArgoCD Image Updater"
    }
    catch {
        Write-WarningMessage "Error during uninstall (continuing): $_"
    }
}

# =============================================================================
# 5. Create argocd-image-updater namespace
# =============================================================================
Write-InfoMessage "Creating namespace '$imageUpdaterNamespace'..."
try {
    kubectl create namespace $imageUpdaterNamespace --dry-run=client -o yaml | kubectl apply -f -
    Write-SuccessMessage "Namespace '$imageUpdaterNamespace' created/updated"
}
catch {
    Write-ErrorMessage "Failed to create namespace: $_"
    exit 1
}

# =============================================================================
# 6. Get ACR credentials from Key Vault
# =============================================================================
Write-InfoMessage "Retrieving ACR credentials from Key Vault..."
try {
    $acrAdminUsername = az keyvault secret show --vault-name $KeyVaultName --name "acr-admin-username" --query "value" -o tsv 2>$null
    $acrAdminPassword = az keyvault secret show --vault-name $KeyVaultName --name "acr-admin-password" --query "value" -o tsv 2>$null

    if (-not $acrAdminUsername -or -not $acrAdminPassword) {
        Write-WarningMessage "ACR credentials not found in Key Vault. Using Azure CLI authentication."
        $acrAdminUsername = "00000000-0000-0000-0000-000000000000"
        $acrAdminPassword = (az acr login --name ($ACRLoginServer -split "\.")[0] --expose-token --output tsv --query accessToken 2>$null)
    }
    else {
        Write-SuccessMessage "ACR credentials retrieved from Key Vault"
    }
}
catch {
    Write-ErrorMessage "Failed to retrieve ACR credentials: $_"
    exit 1
}

# =============================================================================
# 7. Create Docker config secret for ACR access
# =============================================================================
Write-InfoMessage "Creating Docker registry secret for ACR access..."
try {
    # Create docker-config.json
    $dockerConfig = @{
        auths = @{
            $ACRLoginServer = @{
                username = $acrAdminUsername
                password = $acrAdminPassword
                auth     = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${acrAdminUsername}:${acrAdminPassword}"))
            }
        }
    }

    $dockerConfigJson = $dockerConfig | ConvertTo-Json -Compress
    $dockerConfigBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dockerConfigJson))

    # Create Secret manifest
    $secretManifest = @"
apiVersion: v1
kind: Secret
metadata:
  name: argocd-image-updater-acr-creds
  namespace: $imageUpdaterNamespace
type: Opaque
data:
  registries.conf: $(
    $registriesConf = @"
registries:
- name: $ACRLoginServer
  api_url: https://$ACRLoginServer
  ping: yes
  insecure: no
  credentials: pull-secret
  prefix: $ACRLoginServer
  tagsortingstrategy: latest
"@
    [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($registriesConf))
  )
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-image-updater-docker-config
  namespace: $imageUpdaterNamespace
type: kubernetes.io/dockercfg
data:
  .dockercfg: $dockerConfigBase64
"@

    $secretManifest | kubectl apply -f -
    Write-SuccessMessage "Docker registry secret created"
}
catch {
    Write-ErrorMessage "Failed to create Docker registry secret: $_"
    exit 1
}

# =============================================================================
# 8. Add ArgoCD Helm repository
# =============================================================================
Write-InfoMessage "Adding ArgoCD Helm repository..."
try {
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update argo
    Write-SuccessMessage "ArgoCD Helm repository added"
}
catch {
    Write-ErrorMessage "Failed to add ArgoCD Helm repository: $_"
    exit 1
}

# =============================================================================
# 9. Install ArgoCD Image Updater via Helm
# =============================================================================
Write-InfoMessage "Installing ArgoCD Image Updater via Helm..."
try {
    helm install argocd-image-updater argo/argocd-image-updater `
        --namespace $imageUpdaterNamespace `
        --create-namespace `
        --set argocd.namespace=argocd `
        --set argocd.serverAddress=http://argocd-server.argocd.svc.cluster.local:80 `
        --set config.registries[0].name=$ACRLoginServer `
        --set config.registries[0].api_url=https://$ACRLoginServer `
        --set config.registries[0].ping=true `
        --set config.registries[0].insecure=false `
        --set config.registries[0].credentials=pull-secret `
        --set config.registries[0].prefix=$ACRLoginServer

    Write-SuccessMessage "ArgoCD Image Updater installed successfully"
}
catch {
    Write-ErrorMessage "Failed to install ArgoCD Image Updater: $_"
    exit 1
}

# =============================================================================
# 10. Wait for ArgoCD Image Updater deployment to be ready
# =============================================================================
Write-InfoMessage "Waiting for ArgoCD Image Updater to be ready..."
try {
    kubectl rollout status deployment/argocd-image-updater -n $imageUpdaterNamespace --timeout=300s 2>$null
    Write-SuccessMessage "ArgoCD Image Updater is ready"
}
catch {
    Write-WarningMessage "Timeout waiting for ArgoCD Image Updater to be ready"
    Write-InfoMessage "Checking pod status..."
    kubectl get pods -n $imageUpdaterNamespace
}

# =============================================================================
# 11. Create RBAC permissions
# =============================================================================
Write-InfoMessage "Creating RBAC permissions for ArgoCD Image Updater..."
try {
    $rbacManifest = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-image-updater
rules:
- apiGroups:
  - argoproj.io
  resources:
  - applications
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - argoproj.io
  resources:
  - applications/finalizers
  verbs:
  - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-image-updater
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-image-updater
subjects:
- kind: ServiceAccount
  name: argocd-image-updater
  namespace: $imageUpdaterNamespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: argocd-image-updater
  namespace: argocd
rules:
- apiGroups:
  - ''
  resources:
  - secrets
  verbs:
  - get
  - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-image-updater
  namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-image-updater
subjects:
- kind: ServiceAccount
  name: argocd-image-updater
  namespace: $imageUpdaterNamespace
"@

    $rbacManifest | kubectl apply -f -
    Write-SuccessMessage "RBAC permissions configured"
}
catch {
    Write-ErrorMessage "Failed to configure RBAC: $_"
    exit 1
}

# =============================================================================
# 12. Verify installation
# =============================================================================
Write-InfoMessage "Verifying ArgoCD Image Updater installation..."
try {
    $pods = kubectl get pods -n $imageUpdaterNamespace --selector=app.kubernetes.io/name=argocd-image-updater -o jsonpath='{.items[*].status.phase}'
    
    if ($pods -contains "Running") {
        Write-SuccessMessage "ArgoCD Image Updater is running"
    }
    else {
        Write-WarningMessage "ArgoCD Image Updater pods are not running yet"
        Write-InfoMessage "Current status: $pods"
    }

    Write-InfoMessage "Pod status:"
    kubectl get pods -n $imageUpdaterNamespace
}
catch {
    Write-WarningMessage "Failed to verify installation: $_"
}

# =============================================================================
# 13. Display configuration summary
# =============================================================================
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Success
Write-Host "║     ✅ ArgoCD Image Updater Installed Successfully         ║" -ForegroundColor $Colors.Success
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Success
Write-Host ""
Write-SuccessMessage "Installation Summary:"
Write-Host ""
Write-Host "  Namespace:        $imageUpdaterNamespace" -ForegroundColor $Colors.Muted
Write-Host "  ACR Server:       $ACRLoginServer" -ForegroundColor $Colors.Muted
Write-Host "  ArgoCD Namespace: argocd" -ForegroundColor $Colors.Muted
Write-Host ""
Write-InfoMessage "Next Steps:"
Write-Host ""
Write-Host "  1. Verify deployment annotations in Kubernetes manifests" -ForegroundColor $Colors.Muted
Write-Host "     Example annotation:" -ForegroundColor $Colors.Muted
Write-Host "       argocd-image-updater.argoproj.io/image-list: games=<ACR>/games-api" -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "  2. Check ArgoCD Image Updater logs:" -ForegroundColor $Colors.Muted
Write-Host "     kubectl logs -f -n $imageUpdaterNamespace -l app.kubernetes.io/name=argocd-image-updater" -ForegroundColor $Colors.Muted
Write-Host ""
Write-Host "  3. New images in ACR tagged 'latest' will be automatically detected" -ForegroundColor $Colors.Muted
Write-Host "     and deployments will be updated" -ForegroundColor $Colors.Muted
Write-Host ""
