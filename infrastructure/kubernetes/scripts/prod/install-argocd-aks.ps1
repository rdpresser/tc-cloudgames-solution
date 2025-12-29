<#
.SYNOPSIS
  Installs ArgoCD on Azure AKS cluster.
  
.DESCRIPTION
  This script installs ArgoCD on an Azure AKS cluster using Helm.
  It can be run locally (with az cli and kubectl configured) or 
  directly in Azure Cloud Shell.
  
  Features:
  - Installs ArgoCD via Helm with LoadBalancer service
  - Configures admin password
  - Waits for LoadBalancer IP assignment
  - Outputs access information
  
.PARAMETER ResourceGroup
  Azure Resource Group name containing the AKS cluster.
  
.PARAMETER ClusterName
  Name of the AKS cluster.
  
.PARAMETER AdminPassword
  ArgoCD admin password. Minimum 8 characters.
  Default: Argo@AKS123!
  
.PARAMETER Namespace
  Kubernetes namespace for ArgoCD.
  Default: argocd
  
.PARAMETER ChartVersion
  ArgoCD Helm chart version.
  Default: 7.7.16
  
.EXAMPLE
  # Run locally with default password
  .\install-argocd-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.EXAMPLE
  # Run locally with custom password
  .\install-argocd-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -AdminPassword "MySecurePass123!"
  
.EXAMPLE
  # Run in Azure Cloud Shell (copy & paste)
  # 1. Open Azure Cloud Shell (https://shell.azure.com)
  # 2. Switch to PowerShell
  # 3. Run:
  $RG = "tc-cloudgames-solution-dev-rg"
  $CLUSTER = "tc-cloudgames-dev-cr8n-aks"
  $PASSWORD = "Argo@AKS123!"
  
  az aks get-credentials --resource-group $RG --name $CLUSTER --overwrite-existing
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install argocd argo/argo-cd -n argocd --set server.service.type=LoadBalancer --set configs.params."server\.insecure"=true --set configs.secret.argocdServerAdminPassword=$(htpasswd -nbBC 10 "" $PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/')
  kubectl get svc argocd-server -n argocd -w

.NOTES
  Requirements:
  - Azure CLI (az) installed and logged in
  - kubectl installed
  - helm v3 installed
  
  For Azure Cloud Shell: All tools are pre-installed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$AdminPassword = "Argo@AKS123!",
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "argocd",
    
    [Parameter(Mandatory = $false)]
    [string]$ChartVersion = "7.7.16",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# =============================================================================
# Configuration
# =============================================================================
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ArgoCD Installation for Azure AKS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Namespace      : $Namespace" -ForegroundColor White
Write-Host "Chart Version  : $ChartVersion" -ForegroundColor White
Write-Host ""

# =============================================================================
# 0. Check if ArgoCD already exists
# =============================================================================
$existingRelease = helm list -n $Namespace -q 2>$null | Where-Object { $_ -match "argocd" }
if ($existingRelease -and -not $Force) {
    Write-Host "⚠️  ArgoCD is already installed in namespace '$Namespace'" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Do you want to REINSTALL ArgoCD? This will DELETE and recreate it. (y/N)"
    
    if ($response -ne "y" -and $response -ne "Y") {
        <#
        .SYNOPSIS
            Installs Argo CD on AKS using the official YAML manifests (no Helm).

        .DESCRIPTION
            Applies the official Argo CD install manifest via kubectl using a generated
            kustomization.yaml to set the target namespace. This avoids Terraform/Helm
            access issues to the cluster and keeps the flow simple and reproducible.

            Features:
            - Installs Argo CD via YAML (kubectl apply -k)
            - Namespace override (default: "default") to avoid overwriting existing installs
            - Optional version pinning (e.g., v2.11.7, default: stable)
            - Optional bootstrap: apply Argo CD Applications after install

        .PARAMETER ResourceGroup
            Azure Resource Group name containing the AKS cluster.

        .PARAMETER ClusterName
            Name of the AKS cluster.

        .PARAMETER Namespace
            Kubernetes namespace to install Argo CD into. Default: "default".

        .PARAMETER Version
            Argo CD install manifest version tag (e.g., "stable" or "v2.11.7"). Default: "stable".

        .PARAMETER Bootstrap
            If set, bootstraps the Argo CD applications after installing Argo CD.

        .EXAMPLE
            .\install-argocd-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"

        .EXAMPLE
            .\install-argocd-aks.ps1 -ResourceGroup "rg" -ClusterName "aks" -Namespace "argocd-test" -Version "v2.11.7" -Bootstrap

        .NOTES
            Requirements:
            - Azure CLI (az) installed and logged in
            - kubectl installed
            - PowerShell 7+

            This script intentionally avoids Helm. Access Argo CD via port-forward or create your own Service/Ingress if needed.
        #>

        [CmdletBinding()]
        param(
                [Parameter(Mandatory = $true)]
                [string]$ResourceGroup,

                [Parameter(Mandatory = $true)]
                [string]$ClusterName,

                [Parameter(Mandatory = $false)]
                [string]$Namespace = "default",

                [Parameter(Mandatory = $false)]
                [string]$Version = "stable",

                [Parameter(Mandatory = $false)]
                [switch]$Bootstrap
        )

        # =============================================================================
        # Configuration
        # =============================================================================
        $ErrorActionPreference = "Stop"

        Write-Host "";
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  Argo CD Installation (YAML) for Azure AKS" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
        Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
        Write-Host "Namespace      : $Namespace" -ForegroundColor White
        Write-Host "Version       : $Version" -ForegroundColor White
        Write-Host "Bootstrap     : $Bootstrap" -ForegroundColor White
        Write-Host ""

        # =============================================================================
        # 1. Check Prerequisites and Connect
        # =============================================================================
        foreach ($cmd in @("az", "kubectl")) {
                if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
                        Write-Host "ERROR: Required command '$cmd' is not installed or not on PATH." -ForegroundColor Red
                        exit 1
                }
        }

        Write-Host "Getting AKS credentials..." -ForegroundColor Yellow
        az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing | Out-Null

        try {
                kubectl cluster-info | Out-Null
                Write-Host "✅ Cluster is accessible" -ForegroundColor Green
        }
        catch {
                Write-Host "ERROR: Cannot connect to AKS cluster." -ForegroundColor Red
                exit 1
        }

        # =============================================================================
        # 2. Prepare namespace and temp kustomization
        # =============================================================================
        kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null

        $remote = "https://raw.githubusercontent.com/argoproj/argo-cd/$Version/manifests/install.yaml"
        $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "argocd-yaml-" + [Guid]::NewGuid().ToString()))
        $kustomization = @"
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization
        namespace: $Namespace
        resources:
            - $remote
        "@
        Set-Content -Path (Join-Path $tempDir "kustomization.yaml") -Value $kustomization -Encoding UTF8

        # =============================================================================
        # 3. Detect existing Argo CD to avoid surprises
        # =============================================================================
        $existingAnyNs = kubectl get deployments --all-namespaces -o json 2>$null |
                ConvertFrom-Json |
                Select-Object -ExpandProperty items |
                Where-Object { $_.metadata.name -like "argocd-*" }

        if ($existingAnyNs) {
                $installedNs = ($existingAnyNs | Select-Object -First 1).metadata.namespace
                Write-Host "⚠️  Detected existing Argo CD components in namespace '$installedNs'." -ForegroundColor Yellow
                Write-Host "    Proceeding will install another instance in namespace '$Namespace'." -ForegroundColor Yellow
        }

        # =============================================================================
        # 4. Apply Argo CD manifests via kustomize
        # =============================================================================
        Write-Host "Applying Argo CD manifests (namespace '$Namespace', version '$Version')..." -ForegroundColor Yellow
        kubectl apply -k $tempDir.FullName

        if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Failed to apply Argo CD manifests." -ForegroundColor Red
                exit 1
        }
        Write-Host "✅ Argo CD YAML applied" -ForegroundColor Green

        # Wait for Argo CD server
        Write-Host "Waiting for Argo CD server to become Ready..." -ForegroundColor Yellow
        kubectl rollout status deployment/argocd-server -n $Namespace --timeout=180s || Write-Host "ℹ️  argocd-server not ready yet; you can check later." -ForegroundColor Yellow

        Write-Host ""; Write-Host "Access options:" -ForegroundColor White
        Write-Host "  - Port-forward: kubectl port-forward svc/argocd-server -n $Namespace 8080:80" -ForegroundColor Gray
        Write-Host "  - Get initial admin password: kubectl -n $Namespace get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d" -ForegroundColor Gray

        # =============================================================================
        # 5. Optional bootstrap of applications
        # =============================================================================
        if ($Bootstrap) {
                Write-Host "\nBootstrapping Argo CD Applications..." -ForegroundColor Yellow
                $manifestsRoot = Join-Path $PSScriptRoot "..\..\manifests"
                $bootstrap = Join-Path $manifestsRoot "application-bootstrap.yaml"
                if (Test-Path $bootstrap) {
                        kubectl apply -f $bootstrap | Out-Null
                        Write-Host "✅ Applied application-bootstrap.yaml" -ForegroundColor Green
                } else {
                        Write-Host "⚠️  application-bootstrap.yaml not found; skipping." -ForegroundColor Yellow
                }

                $proj = Join-Path $manifestsRoot "application-cloudgames-prod.yaml"
                if (Test-Path $proj) {
                        kubectl apply -f $proj | Out-Null
                        Write-Host "✅ Applied application-cloudgames-prod.yaml" -ForegroundColor Green
                } else {
                        Write-Host "ℹ️  application-cloudgames-prod.yaml not found; you can apply your desired apps manually." -ForegroundColor Yellow
                }
        }

        Write-Host "\n============================================================" -ForegroundColor Green
        Write-Host "  Argo CD YAML Installation Complete" -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor White
        Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
        Write-Host "  kubectl port-forward svc/argocd-server -n $Namespace 8080:80" -ForegroundColor White
    $svc = kubectl get svc argocd-server -n $Namespace -o json | ConvertFrom-Json
