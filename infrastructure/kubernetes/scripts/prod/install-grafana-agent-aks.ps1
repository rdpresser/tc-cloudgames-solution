<#
.SYNOPSIS
  Installs Grafana Agent on Azure AKS cluster for observability.
  
.DESCRIPTION
  This script installs Grafana Agent on an Azure AKS cluster using Helm.
  Grafana Agent collects metrics, logs, and traces and sends them to Grafana Cloud.
  
  Features:
  - Installs Grafana Agent via Helm
  - Configures Prometheus remote write to Grafana Cloud
  - Optional Loki integration for logs
  - Kubernetes service discovery for auto-scraping
  
.PARAMETER ResourceGroup
  Azure Resource Group name containing the AKS cluster.
  
.PARAMETER ClusterName
  Name of the AKS cluster.
  
.PARAMETER GrafanaCloudPrometheusUrl
  Grafana Cloud Prometheus remote write URL.
  Example: https://prometheus-prod-01-prod-us-east-0.grafana.net/api/prom/push
  
.PARAMETER GrafanaCloudPrometheusUsername
  Grafana Cloud Prometheus username (usually a number).
  
.PARAMETER GrafanaCloudPrometheusApiKey
  Grafana Cloud API key for Prometheus.
  
.PARAMETER Namespace
  Kubernetes namespace for Grafana Agent.
  Default: grafana-agent
  
.PARAMETER ChartVersion
  Grafana Agent Helm chart version.
  Default: 0.42.0
  
.EXAMPLE
  # Interactive mode (will prompt for credentials)
  .\install-grafana-agent-aks.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.EXAMPLE
  # With Grafana Cloud credentials
  .\install-grafana-agent-aks.ps1 `
    -ResourceGroup "tc-cloudgames-solution-dev-rg" `
    -ClusterName "tc-cloudgames-dev-cr8n-aks" `
    -GrafanaCloudPrometheusUrl "https://prometheus-prod-01-prod-us-east-0.grafana.net/api/prom/push" `
    -GrafanaCloudPrometheusUsername "123456" `
    -GrafanaCloudPrometheusApiKey "glc_xxx..."

.NOTES
  Requirements:
  - Azure CLI (az) installed and logged in
  - kubectl installed
  - helm v3 installed
  - Grafana Cloud account with API key
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "tc-cloudgames-solution-dev-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "tc-cloudgames-dev-cr8n-aks",
    
    [Parameter(Mandatory = $false)]
    [string]$GrafanaCloudPrometheusUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$GrafanaCloudPrometheusUsername,
    
    [Parameter(Mandatory = $false)]
    [string]$GrafanaCloudPrometheusApiKey,
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "grafana-agent",
    
    [Parameter(Mandatory = $false)]
    [string]$ChartVersion = "0.42.0",

    [Parameter(Mandatory = $false)]
    [switch]$SkipCredentialsPrompt
)

# =============================================================================
# Configuration
# =============================================================================
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Grafana Agent Installation for Azure AKS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Namespace      : $Namespace" -ForegroundColor White
Write-Host "Chart Version  : $ChartVersion" -ForegroundColor White
Write-Host ""

# =============================================================================
# 1. Check Prerequisites
# =============================================================================
Write-Host "=== 1/5 Checking prerequisites ===" -ForegroundColor Yellow

foreach ($cmd in @("az", "kubectl", "helm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$cmd' not found. Please install it first." -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ All prerequisites installed" -ForegroundColor Green

# =============================================================================
# 2. Get AKS Credentials
# =============================================================================
Write-Host ""
Write-Host "=== 2/5 Getting AKS credentials ===" -ForegroundColor Yellow

$currentContext = kubectl config current-context 2>$null
if ($currentContext -ne $ClusterName) {
    Write-Host "Current context: $currentContext"
    Write-Host "Getting credentials for: $ClusterName"
    az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to get AKS credentials." -ForegroundColor Red
        exit 1
    }
}
Write-Host "✅ AKS credentials configured" -ForegroundColor Green

# =============================================================================
# 3. Get Grafana Cloud Credentials
# =============================================================================
Write-Host ""
Write-Host "=== 3/5 Configuring Grafana Cloud credentials ===" -ForegroundColor Yellow

# Try to get from Azure Key Vault if not provided
if (-not $GrafanaCloudPrometheusUrl -or -not $GrafanaCloudPrometheusUsername -or -not $GrafanaCloudPrometheusApiKey) {
    Write-Host "Attempting to get credentials from Azure Key Vault..." -ForegroundColor Gray
    
    $keyVaultName = "tccloudgamesdevcr8nkv"
    
    try {
        if (-not $GrafanaCloudPrometheusUrl) {
            $GrafanaCloudPrometheusUrl = az keyvault secret show --vault-name $keyVaultName --name "grafana-otel-exporter-endpoint" --query "value" -o tsv 2>$null
        }
        if (-not $GrafanaCloudPrometheusUsername) {
            # Username is typically part of the auth header or a separate secret
            $authHeader = az keyvault secret show --vault-name $keyVaultName --name "grafana-otel-auth-header" --query "value" -o tsv 2>$null
            if ($authHeader) {
                # Extract username from Basic auth header if present
                Write-Host "   Found auth header in Key Vault" -ForegroundColor Gray
            }
        }
        if (-not $GrafanaCloudPrometheusApiKey) {
            $GrafanaCloudPrometheusApiKey = az keyvault secret show --vault-name $keyVaultName --name "grafana-otel-prometheus-api-token" --query "value" -o tsv 2>$null
        }
    }
    catch {
        Write-Host "   Could not retrieve all credentials from Key Vault" -ForegroundColor Yellow
    }
}

# Prompt for missing credentials if not skipped
if (-not $SkipCredentialsPrompt) {
    if (-not $GrafanaCloudPrometheusUrl) {
        Write-Host ""
        Write-Host "Grafana Cloud Prometheus URL not found." -ForegroundColor Yellow
        Write-Host "Example: https://prometheus-prod-01-prod-us-east-0.grafana.net/api/prom/push" -ForegroundColor Gray
        $GrafanaCloudPrometheusUrl = Read-Host "Enter Grafana Cloud Prometheus URL (or press Enter to skip)"
    }
    
    if (-not $GrafanaCloudPrometheusUsername -and $GrafanaCloudPrometheusUrl) {
        $GrafanaCloudPrometheusUsername = Read-Host "Enter Grafana Cloud Prometheus Username"
    }
    
    if (-not $GrafanaCloudPrometheusApiKey -and $GrafanaCloudPrometheusUrl) {
        $GrafanaCloudPrometheusApiKey = Read-Host "Enter Grafana Cloud API Key" -AsSecureString
        $GrafanaCloudPrometheusApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($GrafanaCloudPrometheusApiKey))
    }
}

$hasGrafanaCloud = $GrafanaCloudPrometheusUrl -and $GrafanaCloudPrometheusUsername -and $GrafanaCloudPrometheusApiKey

if ($hasGrafanaCloud) {
    Write-Host "✅ Grafana Cloud credentials configured" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Grafana Cloud credentials not provided - installing without remote write" -ForegroundColor Yellow
    Write-Host "   Grafana Agent will only collect local metrics" -ForegroundColor Gray
}

# =============================================================================
# 4. Setup Helm Repository
# =============================================================================
Write-Host ""
Write-Host "=== 4/5 Setting up Helm repository ===" -ForegroundColor Yellow

helm repo add grafana https://grafana.github.io/helm-charts 2>$null
helm repo update
Write-Host "✅ Helm repository configured" -ForegroundColor Green

# =============================================================================
# 5. Install Grafana Agent
# =============================================================================
Write-Host ""
Write-Host "=== 5/5 Installing Grafana Agent ===" -ForegroundColor Yellow

# Create namespace
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Create secret for Grafana Cloud credentials if available
if ($hasGrafanaCloud) {
    Write-Host "Creating Grafana Cloud credentials secret..."
    
    $secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: grafana-cloud-credentials
  namespace: $Namespace
type: Opaque
stringData:
  prometheus-url: "$GrafanaCloudPrometheusUrl"
  prometheus-username: "$GrafanaCloudPrometheusUsername"
  prometheus-api-key: "$GrafanaCloudPrometheusApiKey"
"@
    
    $secretYaml | kubectl apply -f -
}

# Build Helm values
$helmValues = @"
agent:
  mode: flow
  clustering:
    enabled: false
  configMap:
    content: |
      // =============================================================================
      // Grafana Agent Flow Configuration
      // =============================================================================
      
      logging {
        level = "info"
        format = "logfmt"
      }
      
      // Kubernetes service discovery
      discovery.kubernetes "pods" {
        role = "pod"
      }
      
      discovery.kubernetes "nodes" {
        role = "node"
      }
      
      discovery.kubernetes "services" {
        role = "service"
      }
      
      // Scrape Kubernetes nodes
      prometheus.scrape "nodes" {
        targets    = discovery.kubernetes.nodes.targets
        forward_to = [prometheus.relabel.filter.receiver]
        
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        tls_config {
          insecure_skip_verify = true
        }
      }
      
      // Scrape pods with prometheus annotations
      prometheus.scrape "pods" {
        targets    = discovery.kubernetes.pods.targets
        forward_to = [prometheus.relabel.filter.receiver]
      }
      
      // Filter and relabel metrics
      prometheus.relabel "filter" {
        rule {
          source_labels = ["__name__"]
          regex         = "(up|container_.*|kube_.*|node_.*)"
          action        = "keep"
        }
        forward_to = [prometheus.remote_write.grafana_cloud.receiver]
      }
      
$(if ($hasGrafanaCloud) {
@"
      // Remote write to Grafana Cloud
      prometheus.remote_write "grafana_cloud" {
        endpoint {
          url = "$GrafanaCloudPrometheusUrl"
          
          basic_auth {
            username = "$GrafanaCloudPrometheusUsername"
            password = "$GrafanaCloudPrometheusApiKey"
          }
        }
      }
"@
} else {
@"
      // Remote write disabled - no Grafana Cloud credentials
      prometheus.remote_write "grafana_cloud" {
        // Placeholder - configure with actual Grafana Cloud credentials
        endpoint {
          url = "http://localhost:9090/api/v1/write"
        }
      }
"@
})

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

# Save values to temp file
$valuesFile = [System.IO.Path]::GetTempFileName() + ".yaml"
$helmValues | Out-File -FilePath $valuesFile -Encoding utf8

Write-Host "Installing Grafana Agent Helm chart version $ChartVersion..."

helm upgrade --install grafana-agent grafana/grafana-agent `
    --namespace $Namespace `
    --version $ChartVersion `
    --values $valuesFile `
    --wait `
    --timeout 10m

# Cleanup temp file
Remove-Item $valuesFile -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Helm installation failed." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Grafana Agent installed successfully" -ForegroundColor Green

# =============================================================================
# Output Results
# =============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Grafana Agent Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

if ($hasGrafanaCloud) {
    Write-Host "📊 Metrics are being sent to Grafana Cloud" -ForegroundColor Cyan
    Write-Host "   URL: $GrafanaCloudPrometheusUrl" -ForegroundColor Gray
}
else {
    Write-Host "⚠️  Grafana Agent installed without remote write" -ForegroundColor Yellow
    Write-Host "   Configure Grafana Cloud credentials to send metrics" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  # Check pods status" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host ""
Write-Host "  # View agent logs" -ForegroundColor Gray
Write-Host "  kubectl logs -n $Namespace -l app.kubernetes.io/name=grafana-agent -f" -ForegroundColor White
Write-Host ""
Write-Host "  # Check agent config" -ForegroundColor Gray
Write-Host "  kubectl get configmap -n $Namespace grafana-agent -o yaml" -ForegroundColor White
Write-Host ""
