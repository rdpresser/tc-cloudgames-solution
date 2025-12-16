<#
.SYNOPSIS
  Installs Grafana Agent on AKS cluster.

.DESCRIPTION
  Installs Grafana Agent using Helm with production-ready configuration for metrics collection.
  Supports idempotent operations with -Force parameter for reinstallation.

.PARAMETER ResourceGroup
  Azure Resource Group name.

.PARAMETER ClusterName
  AKS cluster name.

.PARAMETER Force
  Forces reinstallation by uninstalling existing release first.
  Default behavior is to upgrade in-place.

.EXAMPLE
  .\install-grafana-agent.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"

.EXAMPLE
  .\install-grafana-agent.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Grafana Agent Installation" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Prerequisites Check
# =============================================================================
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

foreach ($cmd in @("az", "kubectl", "helm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "❌ ERROR: '$cmd' not found. Please install it first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All prerequisites available" -ForegroundColor Green

# =============================================================================
# Connect to AKS
# =============================================================================
Write-Host ""
Write-Host "Connecting to AKS cluster..." -ForegroundColor Yellow

az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get AKS credentials" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connected to cluster: $ClusterName" -ForegroundColor Green

# =============================================================================
# Check Existing Installation
# =============================================================================
$namespace = "grafana-agent"
$chartVersion = "0.42.0"

Write-Host ""
Write-Host "Checking for existing Grafana Agent installation..." -ForegroundColor Yellow

$existingRelease = helm list -n $namespace -q 2>$null | Where-Object { $_ -match "grafana-agent" }

if ($existingRelease) {
    if ($Force) {
        Write-Host "🔄 Force mode: Uninstalling existing Grafana Agent release..." -ForegroundColor Yellow
        helm uninstall grafana-agent -n $namespace --wait 2>$null
        
        Write-Host "   Deleting namespace..." -ForegroundColor Gray
        kubectl delete namespace $namespace --timeout=60s 2>$null
        
        Start-Sleep -Seconds 3
        Write-Host "✅ Existing installation removed" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Grafana Agent already installed - performing in-place upgrade" -ForegroundColor Cyan
    }
} else {
    Write-Host "ℹ️  No existing installation found - performing fresh install" -ForegroundColor Cyan
}

# =============================================================================
# Add Helm Repository
# =============================================================================
Write-Host ""
Write-Host "Configuring Helm repository..." -ForegroundColor Yellow

helm repo add grafana https://grafana.github.io/helm-charts 2>$null
helm repo update

Write-Host "✅ Helm repository configured" -ForegroundColor Green

# =============================================================================
# Create Namespace
# =============================================================================
Write-Host ""
Write-Host "Ensuring namespace exists..." -ForegroundColor Yellow

kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -

Write-Host "✅ Namespace ready: $namespace" -ForegroundColor Green

# =============================================================================
# Prepare Helm Values
# =============================================================================
Write-Host ""
Write-Host "Preparing Grafana Agent configuration..." -ForegroundColor Yellow

$grafanaValues = @"
agent:
    mode: flow
    clustering:
        enabled: false
    configMap:
        content: |
            logging {
                level = "info"
                format = "logfmt"
            }
            
            discovery.kubernetes "pods" {
                role = "pod"
            }
            
            discovery.kubernetes "nodes" {
                role = "node"
            }
            
            discovery.kubernetes "services" {
                role = "service"
            }
            
            prometheus.scrape "nodes" {
                targets    = discovery.kubernetes.nodes.targets
                forward_to = [prometheus.relabel.filter.receiver]
                bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
                tls_config {
                    insecure_skip_verify = true
                }
            }
            
            prometheus.scrape "pods" {
                targets    = discovery.kubernetes.pods.targets
                forward_to = [prometheus.relabel.filter.receiver]
            }
            
            prometheus.relabel "filter" {
                rule {
                    source_labels = ["__name__"]
                    regex = "(up|container_.*|kube_.*|node_.*)"
                    action = "keep"
                }
                forward_to = [prometheus.remote_write.grafana_cloud.receiver]
            }
            
            prometheus.remote_write "grafana_cloud" {
                endpoint {
                    url = "http://localhost:9090/api/v1/write"
                }
            }

controller:
    type: deployment
    replicas: 1

resources:
    requests:
        cpu: 100m
        memory: 128Mi
    limits:
        cpu: 500m
        memory: 512Mi

serviceAccount:
    create: true
    name: grafana-agent

rbac:
    create: true
"@

$valuesFile = [System.IO.Path]::GetTempFileName() + ".yaml"
$grafanaValues | Out-File -FilePath $valuesFile -Encoding utf8

Write-Host "✅ Configuration prepared" -ForegroundColor Green

# =============================================================================
# Install/Upgrade Grafana Agent
# =============================================================================
Write-Host ""
Write-Host "Installing Grafana Agent (version $chartVersion)..." -ForegroundColor Yellow
Write-Host ""

helm upgrade --install grafana-agent grafana/grafana-agent `
    --namespace $namespace `
    --version $chartVersion `
    --values $valuesFile `
    --wait `
    --timeout 10m

# Clean up temp values file
Remove-Item $valuesFile -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Helm installation failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Grafana Agent installed successfully" -ForegroundColor Green

# =============================================================================
# Summary
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure remote_write endpoint for Grafana Cloud" -ForegroundColor Gray
Write-Host "  2. Update agent configuration with your metrics endpoint" -ForegroundColor Gray
Write-Host "  3. Verify metrics collection in Grafana" -ForegroundColor Gray
Write-Host ""
Write-Host "ℹ️  Note: Current configuration uses a placeholder endpoint" -ForegroundColor Cyan
Write-Host "   Update the remote_write URL in the agent ConfigMap" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Verification
# =============================================================================
Write-Host "📊 Current Status:" -ForegroundColor Cyan
Write-Host ""
kubectl get pods -n $namespace
Write-Host ""
kubectl get configmap -n $namespace

Write-Host ""
