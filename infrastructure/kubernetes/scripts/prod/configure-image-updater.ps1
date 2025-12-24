#Requires -Version 7.0
<#
.SYNOPSIS
Configures ArgoCD Image Updater for automatic ACR image updates — IDEMPOTENT

.DESCRIPTION
Unified script that:
- Installs ArgoCD Image Updater via Helm (if missing)
- Configures authentication to ACR (Secret-based OR Workload Identity)
- Applies ImageUpdater CRD (optional)
- Configures annotations on ArgoCD Applications (RECOMMENDED)
- Fully idempotent: can be run multiple times safely

.PARAMETER ResourceGroup
Azure Resource Group (e.g., tc-cloudgames-solution-dev-rg)

.PARAMETER ClusterName
AKS cluster name (e.g., tc-cloudgames-dev-cr8n-aks)

.PARAMETER AcrName
ACR name without suffix (e.g., tccloudgamesdevcr8nacr)

.PARAMETER AcrPassword
ACR password. If not provided, tries to fetch via Azure CLI

.PARAMETER UseWorkloadIdentity
If $true, sets up Workload Identity (more secure). If $false, uses secret-based auth.

.PARAMETER Force
If $true, reinstalls even if present (uninstall + install)

.PARAMETER SkipAnnotations
If $true, does NOT update Applications with annotations (uses CRD only)

.EXAMPLE
# Full install with secret-based auth
.\configure-image-updater.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks" `
  -AcrName "tccloudgamesdevcr8nacr"

.EXAMPLE
# Install with Workload Identity (more secure)
.\configure-image-updater.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks" `
  -AcrName "tccloudgamesdevcr8nacr" `
  -UseWorkloadIdentity

.EXAMPLE
# Force reinstall
.\configure-image-updater.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" `
  -ClusterName "tc-cloudgames-dev-cr8n-aks" `
  -AcrName "tccloudgamesdevcr8nacr" `
  -Force

.NOTES
This script is idempotent and can be executed multiple times.
Dependencies: kubectl, helm, az (if using Workload Identity)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "tc-cloudgames-solution-dev-rg",

    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "tc-cloudgames-dev-cr8n-aks",

    [Parameter(Mandatory = $false)]
    [string]$AcrName = "tccloudgamesdevcr8nacr",

    [string]$AcrPassword,

    [switch]$UseWorkloadIdentity = $true,

    [switch]$Force = $false,

    [switch]$SkipAnnotations = $false
)

$ErrorActionPreference = "Stop"
$script:AcrUrl = "$AcrName.azurecr.io"
$script:Namespace = "argocd-image-updater"

# =====================================================================
# UTILITY FUNCTIONS
# =====================================================================

function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $colors = @{
        'Success' = 'Green'
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Info' = 'Cyan'
        'Question' = 'Magenta'
    }
    $emoji = @{
        'Success' = '✓'
        'Error' = '✗'
        'Warning' = '⚠'
        'Info' = 'ℹ'
        'Question' = '?'
    }
    $color = $colors[$Type] ?? 'White'
    $icon = $emoji[$Type] ?? ' '
    Write-Host "[$icon] $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-HelmReleaseExists {
    param([string]$ReleaseName, [string]$Namespace)
    $release = helm list -n $Namespace -o json 2>&1 | ConvertFrom-Json | Where-Object { $_.name -eq $ReleaseName }
    return $null -ne $release
}

function Test-NamespaceExists {
    param([string]$Namespace)
    $ns = kubectl get namespace $Namespace -o json 2>&1
    return $LASTEXITCODE -eq 0
}

function Get-AcrPasswordFromAzure {
    param([string]$AcrName, [string]$ResourceGroup)
    try {
        $password = az acr credential show `
            -n $AcrName `
            -g $ResourceGroup `
            --query "passwords[0].value" `
            -o tsv 2>&1
        
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($password)) {
            return $password
        }
        return $null
    }
    catch {
        return $null
    }
}

# =====================================================================
# INITIAL VALIDATIONS
# =====================================================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   ArgoCD Image Updater - Unified Configuration         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Status "Validating dependencies..." 'Info'

$requiredCommands = @("kubectl", "helm")
if ($UseWorkloadIdentity) {
    $requiredCommands += "az"
}

foreach ($cmd in $requiredCommands) {
    if (-not (Test-CommandExists $cmd)) {
        Write-Status "Command not found: $cmd" 'Error'
        exit 1
    }
    Write-Status "✓ $cmd installed" 'Success'
}

# Check cluster connection
try {
    $context = kubectl config current-context 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Not connected to a Kubernetes cluster" 'Error'
        exit 1
    }
    Write-Status "Connected to cluster: $context" 'Success'
}
catch {
    Write-Status "Error checking Kubernetes context: $_" 'Error'
    exit 1
}

# =====================================================================
# OBTER CREDENCIAIS ACR
# =====================================================================

if (-not $UseWorkloadIdentity) {
    Write-Status "Mode: Secret-based authentication" 'Info'
    
    if ([string]::IsNullOrWhiteSpace($AcrPassword)) {
        Write-Status "ACR password not provided, attempting to fetch via Azure CLI..." 'Warning'
        $AcrPassword = Get-AcrPasswordFromAzure -AcrName $AcrName -ResourceGroup $ResourceGroup
        
        if ([string]::IsNullOrWhiteSpace($AcrPassword)) {
            Write-Status "Could not obtain ACR password automatically" 'Error'
            Write-Status "Provide via -AcrPassword or configure Azure CLI" 'Error'
            exit 1
        }
        Write-Status "✓ ACR password obtained via Azure CLI" 'Success'
    }
}
else {
    Write-Status "Mode: Workload Identity (Microsoft Entra ID)" 'Info'
}

# =====================================================================
# CHECK EXISTING INSTALLATION
# =====================================================================

Write-Status "Checking existing installation..." 'Info'

$namespaceExists = Test-NamespaceExists -Namespace $script:Namespace
$helmReleaseExists = Test-HelmReleaseExists -ReleaseName "argocd-image-updater" -Namespace $script:Namespace

if ($helmReleaseExists) {
    Write-Status "ArgoCD Image Updater already installed" 'Warning'
    
    if ($Force) {
        Write-Status "Detected -Force, removing existing installation..." 'Warning'
        helm uninstall argocd-image-updater -n $script:Namespace 2>&1 | Out-Null
        kubectl delete namespace $script:Namespace --ignore-not-found=true 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        Write-Status "Previous installation removed" 'Success'
        $namespaceExists = $false
        $helmReleaseExists = $false
    }
    else {
        $response = Read-Host "Reinstall? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Write-Status "Removing existing installation..." 'Warning'
            helm uninstall argocd-image-updater -n $script:Namespace 2>&1 | Out-Null
            kubectl delete namespace $script:Namespace --ignore-not-found=true 2>&1 | Out-Null
            Start-Sleep -Seconds 5
            Write-Status "Previous installation removed" 'Success'
            $namespaceExists = $false
            $helmReleaseExists = $false
        }
        else {
            Write-Status "Keeping existing installation; updating configuration only" 'Info'
        }
    }
}

# =====================================================================
# CRIAR NAMESPACE
# =====================================================================

if (-not $namespaceExists) {
    Write-Status "Creating namespace $script:Namespace..." 'Info'
    kubectl create namespace $script:Namespace 2>&1 | Out-Null
    Write-Status "✓ Namespace created" 'Success'
}
else {
    Write-Status "✓ Namespace already exists" 'Success'
}

# =====================================================================
# CRIAR SECRET (SE SECRET-BASED)
# =====================================================================

if (-not $UseWorkloadIdentity) {
    Write-Status "Creating docker registry secret..." 'Info'
    
    kubectl create secret docker-registry argocd-image-updater-docker-config `
        --docker-server=$script:AcrUrl `
        --docker-username="00000000-0000-0000-0000-000000000000" `
        --docker-password=$AcrPassword `
        --docker-email="ci@cloudgames.local" `
        --namespace=$script:Namespace `
        --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null
    
    Write-Status "✓ Docker registry secret created/updated" 'Success'
}

# =====================================================================
# INSTALAR VIA HELM
# =====================================================================

if (-not $helmReleaseExists) {
    Write-Status "Adding Helm repository..." 'Info'
    helm repo add argo https://argoproj.github.io/argo-helm 2>&1 | Out-Null
    helm repo update argo 2>&1 | Out-Null
    Write-Status "✓ Helm repo updated" 'Success'
    
    Write-Status "Installing ArgoCD Image Updater via Helm..." 'Info'
    helm install argocd-image-updater argo/argocd-image-updater `
        --namespace $script:Namespace `
        --set "serviceAccount.create=true" `
        --set "serviceAccount.name=argocd-image-updater" `
        --set "config.logLevel=info" `
        --set "config.argocd.serverAddress=http://argocd-server.argocd.svc.cluster.local:80" `
        --wait `
        --timeout 5m 2>&1 | Out-Null
    
    Write-Status "✓ Helm chart instalado" 'Success'
    
    Write-Status "Waiting for pod to be ready..." 'Info'
    kubectl rollout status deployment/argocd-image-updater `
        -n $script:Namespace --timeout=5m 2>&1 | Out-Null
    Write-Status "✓ Pod ready" 'Success'
}

# =====================================================================
# CONFIGURAR WORKLOAD IDENTITY (SE HABILITADO)
# =====================================================================

if ($UseWorkloadIdentity) {
    Write-Status "Configuring Workload Identity..." 'Info'
    
    # Get cluster OIDC issuer
    $cluster = az aks show --resource-group $ResourceGroup --name $ClusterName -o json | ConvertFrom-Json
    $oidcIssuerUrl = $cluster.oidcIssuerProfile.issuerUrl
    
    if ([string]::IsNullOrWhiteSpace($oidcIssuerUrl)) {
        Write-Status "Cluster does not have OIDC enabled" 'Error'
        Write-Status "Run: az aks update -g $ResourceGroup -n $ClusterName --enable-oidc-issuer" 'Error'
        exit 1
    }
    
    Write-Status "OIDC Issuer: $oidcIssuerUrl" 'Info'
    
    # Create/Get Azure application (idempotent: reuse if exists, no warning)
    $appName = "image-updater-$ClusterName"
    $app = az ad app list --filter "displayName eq '$appName'" --query "[0]" -o json 2>$null | ConvertFrom-Json
    if (-not $app) {
        Write-Status "Creating Azure AD application..." 'Info'
        $app = az ad app create --display-name $appName -o json | ConvertFrom-Json
        Write-Status "✓ Application created: $($app.appId)" 'Success'
    }
    else {
        Write-Status "✓ Using existing application: $($app.appId)" 'Success'
    }
    $appId = $app.appId

    # Ensure Service Principal exists (idempotent)
    $sp = az ad sp show --id $appId -o json 2>$null | ConvertFrom-Json
    if (-not $sp) {
        az ad sp create --id $appId 2>&1 | Out-Null
        Start-Sleep -Seconds 10
        Write-Status "✓ Service Principal created" 'Success'
    }
    
    # Atribuir AcrPull role
    $acrId = az acr show --name $AcrName --query id -o tsv
    az role assignment create `
        --assignee $appId `
        --role "AcrPull" `
        --scope $acrId 2>&1 | Out-Null
    Write-Status "✓ AcrPull role assigned" 'Success'
    
    # Configurar Federated Credential
    $credentialName = "k8s-serviceaccount"
    az ad app federated-credential delete `
        --id $appId `
        --federated-credential-id $credentialName `
        2>&1 | Out-Null
    
    $federatedCredJson = @{
        name = $credentialName
        issuer = $oidcIssuerUrl
        subject = "system:serviceaccount:$($script:Namespace):argocd-image-updater"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json
    
    $federatedCredJson | az ad app federated-credential create --id $appId --parameters '@-' 2>&1 | Out-Null
    Write-Status "✓ Federated credential configured" 'Success'
    
    # Anotar ServiceAccount
    kubectl patch serviceaccount argocd-image-updater `
        -n $script:Namespace `
        --type merge `
        -p "{`"metadata`":{`"annotations`":{`"azure.workload.identity/client-id`":`"$appId`"}}}" 2>&1 | Out-Null
    
    # Adicionar label ao Deployment
    kubectl patch deployment argocd-image-updater `
        -n $script:Namespace `
        --type merge `
        -p '{"spec":{"template":{"metadata":{"labels":{"azure.workload.identity/use":"true"}}}}}' 2>&1 | Out-Null
    
    Write-Status "✓ Workload Identity configurado" 'Success'
    
    # Reiniciar pod
    kubectl rollout restart deployment argocd-image-updater -n $script:Namespace 2>&1 | Out-Null
    kubectl rollout status deployment argocd-image-updater -n $script:Namespace --timeout=3m 2>&1 | Out-Null
}

# =====================================================================
# ATUALIZAR CONFIGMAP REGISTRIES.CONF
# =====================================================================

Write-Status "Configurando registries.conf..." 'Info'

$registriesConf = @"
registries:
  - api_url: https://$script:AcrUrl
    insecure: false
    name: $script:AcrUrl
    ping: true
    prefix: $script:AcrUrl
"@

kubectl patch configmap argocd-image-updater-config `
    -n $script:Namespace `
    --type merge `
    -p "{`"data`":{`"registries.conf`":`"$registriesConf`"}}" 2>&1 | Out-Null

Write-Status "✓ ConfigMap atualizado" 'Success'

# =====================================================================
# APLICAR CRD IMAGEUPDATER (OPCIONAL)
# =====================================================================

Write-Status "Aplicando CRD ImageUpdater..." 'Info'

$crdPath = Join-Path (Split-Path $PSScriptRoot -Parent) "..\base\image-updater-cr.yaml"
if (Test-Path $crdPath) {
    kubectl apply -f $crdPath 2>&1 | Out-Null
    Write-Status "✓ CRD ImageUpdater aplicado" 'Success'
}
else {
    Write-Status "CRD not found at: $crdPath" 'Warning'
}

# =====================================================================
# ATUALIZAR APPLICATIONS COM ANNOTATIONS (RECOMENDADO)
# =====================================================================

if (-not $SkipAnnotations) {
    Write-Status "Updating ArgoCD Applications with annotations..." 'Info'
    
    $apps = @("cloudgames-prod", "cloudgames-dev")
    
    foreach ($app in $apps) {
        $appExists = kubectl get application $app -n argocd 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Annotating application: $app" 'Info'
            
            $annotations = @{
                "argocd-image-updater.argoproj.io/image-list" = "games=$script:AcrUrl/games-api,users=$script:AcrUrl/users-api,payments=$script:AcrUrl/payms-api"
                "argocd-image-updater.argoproj.io/games.update-strategy" = "newest-build"
                "argocd-image-updater.argoproj.io/users.update-strategy" = "newest-build"
                "argocd-image-updater.argoproj.io/payments.update-strategy" = "newest-build"
                "argocd-image-updater.argoproj.io/write-back-method" = "argocd"
            }
            
            $patchData = @{
                metadata = @{
                    annotations = $annotations
                }
            } | ConvertTo-Json -Depth 5
            
            kubectl patch application $app -n argocd --type merge -p $patchData 2>&1 | Out-Null
            Write-Status "✓ Application $app annotated" 'Success'
        }
        else {
            Write-Status "Application $app not found (ok if not created yet)" 'Warning'
        }
    }
}

# =====================================================================
# RESTART CONTROLLER TO APPLY CHANGES
# =====================================================================

Write-Status "Restarting controller to apply all configurations..." 'Info'
kubectl rollout restart deployment argocd-image-updater -n $script:Namespace 2>&1 | Out-Null
kubectl rollout status deployment argocd-image-updater -n $script:Namespace --timeout=3m 2>&1 | Out-Null
Write-Status "✓ Controller reiniciado" 'Success'

# =====================================================================
# FINAL VALIDATIONS
# =====================================================================

Write-Host ""
Write-Status "=== Final Validations ===" 'Info'

$podStatus = kubectl get pod -n $script:Namespace `
    -l app.kubernetes.io/name=argocd-image-updater `
    -o jsonpath='{.items[0].status.phase}' 2>&1

if ($podStatus -eq "Running") {
    Write-Status "✓ Pod running" 'Success'
}
else {
    Write-Status "Pod status: $podStatus" 'Warning'
}

$crCount = kubectl get imageupdater -n argocd -o go-template='{{len .items}}' 2>&1
Write-Status "ImageUpdater CRs found: $crCount" 'Info'

# =====================================================================
# RESUMO FINAL
# =====================================================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ✓ CONFIGURATION COMPLETED SUCCESSFULLY          ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Status "Configuration:" 'Info'
Write-Status "  ACR: $script:AcrUrl" 'Info'
Write-Status "  Namespace: $script:Namespace" 'Info'
Write-Status "  Authentication: $(if ($UseWorkloadIdentity) { 'Workload Identity' } else { 'Secret-based' })" 'Info'
Write-Status "  Strategy: newest-build (timestamp-based)" 'Info'
Write-Status "  Annotations applied: $(if ($SkipAnnotations) { 'No' } else { 'Yes' })" 'Info'

Write-Host ""
Write-Status "Next steps:" 'Info'
Write-Status "1. Wait 2–3 minutes for the first check" 'Info'
Write-Status "2. Check logs:" 'Info'
Write-Host "   kubectl logs -f -n $script:Namespace -l app.kubernetes.io/name=argocd-image-updater" -ForegroundColor Gray
Write-Status "3. Confirm ArgoCD applications:" 'Info'
Write-Host "   kubectl get app -n argocd" -ForegroundColor Gray
Write-Status "4. Push a new image to ACR and wait ~3 min" 'Info'
Write-Host ""
