<#
.SYNOPSIS
    Reset ArgoCD installation on AKS cluster.

.DESCRIPTION
    This script completely removes ArgoCD from the AKS cluster and reinstalls it
    with a new admin password. Useful when the password is not working or the
    installation is corrupted.

.PARAMETER ResourceGroup
    Azure Resource Group name. Auto-detected from current kubeconfig if not provided.

.PARAMETER ClusterName
    AKS Cluster name. Auto-detected from current kubeconfig if not provided.

.PARAMETER AdminPassword
    New admin password for ArgoCD. Default: Argo@AKS123!

.PARAMETER SkipUninstall
    Skip the uninstall step (useful for fresh install on clean cluster).

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\reset-argocd-aks.ps1
    # Uses default password and auto-detects cluster

.EXAMPLE
    .\reset-argocd-aks.ps1 -AdminPassword "MyNewPassword123!"
    # Uses custom password

.EXAMPLE
    .\reset-argocd-aks.ps1 -Force
    # Skip confirmation prompts
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [string]$AdminPassword = "Argo@AKS123!",

    [switch]$SkipUninstall,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# =============================================================================
# Helper Functions
# =============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n📌 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Get-ClusterInfo {
    Write-Step "Detecting cluster information..."
    
    $context = kubectl config current-context 2>$null
    if (-not $context) {
        throw "No kubectl context found. Please run: az aks get-credentials --resource-group <rg> --name <aks>"
    }
    
    Write-Host "Current context: $context"
    
    # Try to extract from context name (format: aks-name)
    if (-not $script:ClusterName) {
        $script:ClusterName = $context
    }
    
    # Try to get from Azure if not provided
    if (-not $script:ResourceGroup) {
        $clusters = az aks list --query "[?name=='$($script:ClusterName)'].resourceGroup" -o tsv 2>$null
        if ($clusters) {
            $script:ResourceGroup = $clusters
        }
        else {
            # Default for tc-cloudgames
            $script:ResourceGroup = "tc-cloudgames-solution-dev-rg"
            $script:ClusterName = "tc-cloudgames-dev-cr8n-aks"
        }
    }
    
    Write-Host "Resource Group: $script:ResourceGroup"
    Write-Host "Cluster Name: $script:ClusterName"
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $missing = @()
    
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        $missing += "kubectl"
    }
    
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
        $missing += "helm"
    }
    
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        $missing += "az (Azure CLI)"
    }
    
    if ($missing.Count -gt 0) {
        throw "Missing required tools: $($missing -join ', ')"
    }
    
    Write-Success "All prerequisites installed"
}

function Uninstall-ArgoCD {
    Write-Step "Uninstalling ArgoCD..."
    
    # Check if namespace exists
    $nsExists = kubectl get namespace argocd --ignore-not-found -o name 2>$null
    
    if (-not $nsExists) {
        Write-Warning "ArgoCD namespace not found, skipping uninstall"
        # Still clean up CRDs even if namespace doesn't exist
        Remove-ArgoCDCRDs
        return
    }
    
    # 1. Delete all ArgoCD Applications first (to prevent recreation)
    Write-Host "Deleting ArgoCD Applications..."
    kubectl delete applications.argoproj.io --all -n argocd --timeout=60s 2>$null
    kubectl delete applicationsets.argoproj.io --all -n argocd --timeout=60s 2>$null
    kubectl delete appprojects.argoproj.io --all -n argocd --timeout=60s 2>$null
    
    # 2. Try Helm uninstall
    Write-Host "Attempting Helm uninstall..."
    $helmRelease = helm list -n argocd -q 2>$null | Where-Object { $_ -match "argocd" }
    
    if ($helmRelease) {
        Write-Host "Found Helm release: $helmRelease"
        helm uninstall $helmRelease -n argocd --wait --timeout=5m 2>$null
        Write-Success "Helm release uninstalled"
    }
    else {
        Write-Warning "No Helm release found, will delete resources directly"
    }
    
    # 3. Delete all resources in namespace (including those not managed by Helm)
    Write-Host "Deleting all remaining resources in argocd namespace..."
    kubectl delete all --all -n argocd --timeout=60s --force --grace-period=0 2>$null
    
    # 4. Delete other resource types
    Write-Host "Deleting secrets, configmaps, and service accounts..."
    kubectl delete secrets --all -n argocd --timeout=30s --force --grace-period=0 2>$null
    kubectl delete configmaps --all -n argocd --timeout=30s --force --grace-period=0 2>$null
    kubectl delete serviceaccounts --all -n argocd --timeout=30s --force --grace-period=0 2>$null
    kubectl delete roles --all -n argocd --timeout=30s --force --grace-period=0 2>$null
    kubectl delete rolebindings --all -n argocd --timeout=30s --force --grace-period=0 2>$null
    
    # 5. Delete cluster-wide resources (ClusterRoles, ClusterRoleBindings)
    Write-Host "Deleting cluster-wide ArgoCD resources..."
    kubectl delete clusterroles -l app.kubernetes.io/part-of=argocd --timeout=30s 2>$null
    kubectl delete clusterrolebindings -l app.kubernetes.io/part-of=argocd --timeout=30s 2>$null
    
    # 6. Delete the namespace
    Write-Host "Deleting argocd namespace..."
    kubectl delete namespace argocd --timeout=120s 2>$null
    
    # 7. Wait for namespace to be fully deleted
    $maxWait = 120
    $waited = 0
    while ($waited -lt $maxWait) {
        $ns = kubectl get namespace argocd --ignore-not-found -o name 2>$null
        if (-not $ns) {
            break
        }
        Write-Host "Waiting for namespace deletion... ($waited s)"
        Start-Sleep -Seconds 5
        $waited += 5
    }
    
    if ($waited -ge $maxWait) {
        Write-Warning "Namespace deletion timed out, forcing..."
        # Force delete by removing finalizers
        kubectl patch namespace argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>$null
        kubectl delete namespace argocd --force --grace-period=0 2>$null
        Start-Sleep -Seconds 10
    }
    
    # 8. Remove ArgoCD CRDs (independent of Terraform ownership)
    Remove-ArgoCDCRDs
    
    Write-Success "ArgoCD completely uninstalled"
}

function Remove-ArgoCDCRDs {
    Write-Host "Removing ArgoCD Custom Resource Definitions (CRDs)..."
    
    $crds = @(
        "applications.argoproj.io",
        "applicationsets.argoproj.io",
        "appprojects.argoproj.io"
    )
    
    foreach ($crd in $crds) {
        $exists = kubectl get crd $crd --ignore-not-found -o name 2>$null
        if ($exists) {
            Write-Host "  Deleting CRD: $crd"
            # Remove finalizers first to avoid stuck deletion
            kubectl patch crd $crd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>$null
            kubectl delete crd $crd --timeout=60s --force --grace-period=0 2>$null
            
            # Verify deletion
            Start-Sleep -Seconds 2
            $stillExists = kubectl get crd $crd --ignore-not-found -o name 2>$null
            if ($stillExists) {
                Write-Warning "  CRD $crd still exists after deletion attempt"
            } else {
                Write-Host "  ✓ CRD $crd deleted" -ForegroundColor Green
            }
        }
    }
}

function Invoke-InstallScript {
    param([string]$Password)
    
    Write-Step "Installing ArgoCD via install-argocd-aks.ps1..."
    
    $installScript = Join-Path $PSScriptRoot "install-argocd-aks.ps1"
    
    if (-not (Test-Path $installScript)) {
        throw "Install script not found at: $installScript"
    }
    
    # Call the install script with parameters
    & $installScript `
        -ResourceGroup $script:ResourceGroup `
        -ClusterName $script:ClusterName `
        -AdminPassword $Password
    
    if ($LASTEXITCODE -ne 0) {
        throw "Installation script failed with exit code: $LASTEXITCODE"
    }
    
    Write-Success "ArgoCD installation completed via install script"
}

# =============================================================================
# Main Execution
# =============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║              ArgoCD Reset Script for AKS                       ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

try {
    Test-Prerequisites
    Get-ClusterInfo
    
    # Confirmation
    if (-not $Force) {
        Write-Host ""
        Write-Warning "This will COMPLETELY REMOVE and REINSTALL ArgoCD!"
        Write-Warning "All ArgoCD applications and configurations will be LOST!"
        Write-Host ""
        $confirm = Read-Host "Type 'yes' to continue"
        if ($confirm -ne "yes") {
            Write-Host "Operation cancelled."
            exit 0
        }
    }
    
    # Uninstall if not skipped
    if (-not $SkipUninstall) {
        Uninstall-ArgoCD
    }
    
    # Install using the dedicated install script
    Invoke-InstallScript -Password $AdminPassword
    
    Write-Host ""
    Write-Success "ArgoCD reset completed successfully!"
    Write-Host ""
}
catch {
    Write-Error "Error: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
