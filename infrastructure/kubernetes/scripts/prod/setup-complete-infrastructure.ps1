<#
.SYNOPSIS
  Executa o setup completo da infraestrutura após o Terraform apply.
  
.DESCRIPTION
  Este script automatiza todos os passos necessários após o Terraform apply inicial:
  1. Conecta ao cluster AKS
  2. Instala NGINX Ingress Controller
  3. Obtém o IP do LoadBalancer
  4. Atualiza Terraform com o IP do NGINX
  5. Re-executa Terraform para configurar APIM backends
  6. Instala External Secrets Operator
  7. Configura Workload Identity
  8. (Opcional) Instala Grafana Agent
  9. Deploy das aplicações via Kustomize
  
.PARAMETER ResourceGroup
  Azure Resource Group name.
  
.PARAMETER ClusterName
  Nome do cluster AKS.
  
.PARAMETER Environment
  Ambiente: dev, staging, prod
  Default: dev
  
.PARAMETER SkipNginx
  Pula instalação do NGINX Ingress (se já estiver instalado).
  
.PARAMETER SkipGrafana
  Pula instalação do Grafana Agent.
  
.PARAMETER SkipDeploy
  Pula deploy das aplicações.

.PARAMETER Force
    Reinstala componentes (NGINX/ESO/Grafana) mesmo se já instalados.
  
.EXAMPLE
  .\setup-complete-infrastructure.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks"
  
.EXAMPLE
  .\setup-complete-infrastructure.ps1 -ResourceGroup "tc-cloudgames-solution-dev-rg" -ClusterName "tc-cloudgames-dev-cr8n-aks" -SkipNginx -SkipGrafana
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipNginx,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipGrafana,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$terraformDir = Join-Path (Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent) "terraform/foundation"
$k8sDir = Split-Path (Split-Path $scriptDir -Parent) -Parent

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  TC CloudGames - Complete Infrastructure Setup" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group : $ResourceGroup" -ForegroundColor White
Write-Host "Cluster Name   : $ClusterName" -ForegroundColor White
Write-Host "Environment    : $Environment" -ForegroundColor White
Write-Host ""

# =============================================================================
# 1. Connect to AKS
# =============================================================================
Write-Host ""
Write-Host "=== Step 1/9: Connecting to AKS ===" -ForegroundColor Yellow
Write-Host ""

az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to connect to AKS cluster" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Connected to AKS cluster" -ForegroundColor Green
kubectl cluster-info

# =============================================================================
# 2. Install NGINX Ingress (inline)
# =============================================================================
$nginxIP = $null

if (-not $SkipNginx) {
    Write-Host ""
    Write-Host "=== Step 2/9: Installing NGINX Ingress Controller ===" -ForegroundColor Yellow
    Write-Host ""

    $namespace = "ingress-nginx"
    $chartVersion = "4.11.3"

    $existingRelease = helm list -n $namespace -q 2>$null | Where-Object { $_ -match "ingress-nginx" }
    if ($existingRelease) {
        if ($Force) {
            Write-Host "🔄 Force requested: uninstalling existing NGINX before reinstall" -ForegroundColor Yellow
            helm uninstall $existingRelease -n $namespace --wait 2>$null
            kubectl delete namespace $namespace --timeout=60s 2>$null
            Start-Sleep -Seconds 5
        } else {
            Write-Host "ℹ️  NGINX Ingress already installed in '$namespace' - performing upgrade in-place" -ForegroundColor Cyan
        }
    }

    foreach ($cmd in @("az", "kubectl", "helm")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-Host "ERROR: '$cmd' not found. Please install it first." -ForegroundColor Red
            exit 1
        }
    }

    az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Failed to get AKS credentials." -ForegroundColor Red; exit 1 }

    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null
    helm repo update

    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -

    Write-Host "Installing NGINX Ingress Helm chart version $chartVersion..."
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
        --namespace $namespace `
        --version $chartVersion `
        --set controller.service.type=LoadBalancer `
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz `
        --set controller.metrics.enabled=true `
        --set controller.metrics.serviceMonitor.enabled=false `
        --set controller.resources.limits.cpu=500m `
        --set controller.resources.limits.memory=512Mi `
        --set controller.resources.requests.cpu=250m `
        --set controller.resources.requests.memory=256Mi `
        --set controller.admissionWebhooks.enabled=true `
        --set controller.admissionWebhooks.patch.enabled=true `
        --set defaultBackend.enabled=true `
        --set defaultBackend.resources.limits.cpu=50m `
        --set defaultBackend.resources.limits.memory=64Mi `
        --set defaultBackend.resources.requests.cpu=25m `
        --set defaultBackend.resources.requests.memory=32Mi `
        --wait `
        --timeout 10m

    if ($LASTEXITCODE -ne 0) { Write-Host "❌ Helm install failed for NGINX" -ForegroundColor Red; exit 1 }
    Write-Host "✅ NGINX Ingress installed" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "=== Step 2/9: Skipping NGINX Ingress (already installed) ===" -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# 3. Get NGINX LoadBalancer IP
# =============================================================================
Write-Host ""
Write-Host "=== Step 3/9: Getting NGINX LoadBalancer IP ===" -ForegroundColor Yellow
Write-Host ""

$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts -and -not $nginxIP) {
    $attempt++
    $svc = kubectl get svc ingress-nginx-controller -n ingress-nginx -o json 2>$null | ConvertFrom-Json
    if ($svc -and $svc.status.loadBalancer.ingress) {
        $nginxIP = $svc.status.loadBalancer.ingress[0].ip
    }
    
    if (-not $nginxIP) {
        Write-Host "   Waiting for LoadBalancer IP... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

if (-not $nginxIP) {
    Write-Host "❌ Failed to get NGINX LoadBalancer IP" -ForegroundColor Red
    exit 1
}

Write-Host "✅ NGINX LoadBalancer IP: $nginxIP" -ForegroundColor Green

# =============================================================================
# 4. Update Terraform Variables
# =============================================================================
Write-Host ""
Write-Host "=== Step 4/9: Updating Terraform Variables ===" -ForegroundColor Yellow
Write-Host ""

$tfvarsFile = Join-Path $terraformDir "terraform.tfvars"

# Check if terraform.tfvars exists
if (-not (Test-Path $tfvarsFile)) {
    Write-Host "Creating terraform.tfvars file..." -ForegroundColor Cyan
    "" | Out-File -Encoding UTF8 $tfvarsFile
}

# Read existing content
$tfvarsContent = Get-Content $tfvarsFile -Raw -ErrorAction SilentlyContinue
if (-not $tfvarsContent) { $tfvarsContent = "" }

# Remove old nginx_ingress_ip if exists
$tfvarsContent = $tfvarsContent -replace 'nginx_ingress_ip\s*=\s*"[^"]*"', ''

# Add new nginx_ingress_ip
$tfvarsContent = $tfvarsContent.TrimEnd() + "`n`nnginx_ingress_ip = `"$nginxIP`"`n"

# Write back
$tfvarsContent | Out-File -Encoding UTF8 $tfvarsFile

Write-Host "✅ Updated terraform.tfvars with nginx_ingress_ip = `"$nginxIP`"" -ForegroundColor Green

# =============================================================================
# 5. Re-run Terraform to Update APIM
# =============================================================================
Write-Host ""
Write-Host "=== Step 5/9: Re-running Terraform to Update APIM Backends ===" -ForegroundColor Yellow
Write-Host ""

Push-Location $terraformDir

Write-Host "Running terraform plan..." -ForegroundColor Cyan
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Terraform plan failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ""
$response = Read-Host "Apply Terraform changes to update APIM backends? (Y/n)"
if ($response -ne "n" -and $response -ne "N") {
    terraform apply tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform apply failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    Write-Host "✅ Terraform apply completed" -ForegroundColor Green
} else {
    Write-Host "⚠️  Skipped Terraform apply. APIM backends may not be configured correctly." -ForegroundColor Yellow
}

Pop-Location

# =============================================================================
# 6. Install External Secrets Operator (inline)
# =============================================================================
Write-Host ""
Write-Host "=== Step 6/9: Installing External Secrets Operator ===" -ForegroundColor Yellow
Write-Host ""

$esoNamespace = "external-secrets"
$esoChartVersion = "0.9.11"

$existingEso = helm list -n $esoNamespace -q 2>$null | Where-Object { $_ -match "external-secrets" }
if ($existingEso) {
    if ($Force) {
        Write-Host "🔄 Force requested: uninstalling existing ESO before reinstall" -ForegroundColor Yellow
        helm uninstall $existingEso -n $esoNamespace --wait 2>$null
        kubectl delete namespace $esoNamespace --timeout=60s 2>$null
        Start-Sleep -Seconds 5
    } else {
        Write-Host "ℹ️  ESO already installed - performing upgrade in-place" -ForegroundColor Cyan
    }
}

helm repo add external-secrets https://charts.external-secrets.io 2>$null
helm repo update

kubectl create namespace $esoNamespace --dry-run=client -o yaml | kubectl apply -f -

$helmArgs = @(
    "upgrade", "--install", "external-secrets", "external-secrets/external-secrets",
    "--namespace", $esoNamespace,
    "--version", $esoChartVersion,
    "--set", "installCRDs=true",
    "--set", "webhook.port=9443",
    "--set", "resources.limits.cpu=200m",
    "--set", "resources.limits.memory=256Mi",
    "--set", "resources.requests.cpu=100m",
    "--set", "resources.requests.memory=128Mi",
    "--wait", "--timeout", "5m"
)

helm @helmArgs
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Helm install failed for ESO" -ForegroundColor Red; exit 1 }

Start-Sleep -Seconds 5
Write-Host "✅ External Secrets Operator installed" -ForegroundColor Green

# =============================================================================
# 7. Setup Workload Identity for ESO (inline)
# =============================================================================
Write-Host ""
Write-Host "=== Step 7/9: Configuring Workload Identity ===" -ForegroundColor Yellow
Write-Host ""

$keyVaultName = if ($KeyVaultName) { $KeyVaultName } else { "tccloudgamesdevcr8nkv" }
$esoNamespace = "external-secrets"
$esoServiceAccount = "external-secrets"
$identityName = "$ClusterName-eso-identity"

# Step 1: Check ESO is installed
$esoPods = kubectl get pods -n $esoNamespace --no-headers 2>$null | Where-Object { $_ -match "Running" }
if (-not $esoPods) {
    Write-Host "❌ External Secrets Operator not running" -ForegroundColor Red
    exit 1
}

# Step 2: Get AKS OIDC Issuer URL
$aks = az aks show --resource-group $ResourceGroup --name $ClusterName 2>$null | ConvertFrom-Json
if (-not $aks) {
    Write-Host "❌ AKS cluster not found" -ForegroundColor Red
    exit 1
}

$oidcIssuerUrl = $aks.oidcIssuerProfile.issuerUrl
if (-not $oidcIssuerUrl) {
    Write-Host "❌ OIDC Issuer not enabled on AKS cluster" -ForegroundColor Red
    exit 1
}

$tenantId = (az account show 2>$null | ConvertFrom-Json).tenantId
Write-Host "✅ OIDC Issuer URL obtained" -ForegroundColor Green

# Step 3: Create User Assigned Identity
$ErrorActionPreference = "SilentlyContinue"
$existingIdentityJson = az identity show --name $identityName --resource-group $ResourceGroup 2>&1
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -eq 0 -and $existingIdentityJson) {
    $existingIdentity = $existingIdentityJson | ConvertFrom-Json
    $clientId = $existingIdentity.clientId
    $principalId = $existingIdentity.principalId
    Write-Host "ℹ️  Identity '$identityName' already exists" -ForegroundColor Cyan
} else {
    Write-Host "   Creating identity '$identityName'..." -ForegroundColor Cyan
    $identityJson = az identity create --name $identityName --resource-group $ResourceGroup --location $aks.location 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create identity" -ForegroundColor Red
        exit 1
    }
    $identity = $identityJson | ConvertFrom-Json
    $clientId = $identity.clientId
    $principalId = $identity.principalId
    Write-Host "✅ Identity created" -ForegroundColor Green
    Start-Sleep -Seconds 15
}

# Step 4: Create Federated Identity Credential
$fedCredName = "$identityName-federated-credential"
$subject = "system:serviceaccount:${esoNamespace}:${esoServiceAccount}"

$ErrorActionPreference = "SilentlyContinue"
$existingFedCredJson = az identity federated-credential show --name $fedCredName --identity-name $identityName --resource-group $ResourceGroup 2>&1
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -ne 0 -or -not $existingFedCredJson) {
    az identity federated-credential create `
        --name $fedCredName `
        --identity-name $identityName `
        --resource-group $ResourceGroup `
        --issuer $oidcIssuerUrl `
        --subject $subject `
        --audiences "api://AzureADTokenExchange" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create federated credential" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Federated credential created" -ForegroundColor Green
}

# Step 5: Grant Key Vault Access
$kv = az keyvault show --name $keyVaultName 2>$null | ConvertFrom-Json
if (-not $kv) {
    Write-Host "❌ Key Vault '$keyVaultName' not found" -ForegroundColor Red
    exit 1
}

az role assignment create `
    --role "Key Vault Secrets User" `
    --assignee-object-id $principalId `
    --assignee-principal-type ServicePrincipal `
    --scope $kv.id 2>$null | Out-Null

Write-Host "✅ Key Vault access granted" -ForegroundColor Green

# Step 6: Annotate ESO ServiceAccount
kubectl annotate serviceaccount $esoServiceAccount -n $esoNamespace `
    "azure.workload.identity/client-id=$clientId" --overwrite 2>$null
kubectl label serviceaccount $esoServiceAccount -n $esoNamespace `
    "azure.workload.identity/use=true" --overwrite 2>$null

kubectl annotate serviceaccount external-secrets-webhook -n $esoNamespace `
    "azure.workload.identity/client-id=$clientId" --overwrite 2>$null
kubectl label serviceaccount external-secrets-webhook -n $esoNamespace `
    "azure.workload.identity/use=true" --overwrite 2>$null

Write-Host "   Restarting ESO pods..." -ForegroundColor Cyan
kubectl rollout restart deployment/external-secrets -n $esoNamespace 2>$null
kubectl rollout restart deployment/external-secrets-webhook -n $esoNamespace 2>$null
kubectl rollout restart deployment/external-secrets-cert-controller -n $esoNamespace 2>$null

kubectl rollout status deployment/external-secrets -n $esoNamespace --timeout=120s 2>$null

# Step 7: Recreate ClusterSecretStore
$kvUrl = "https://$keyVaultName.vault.azure.net"

$manifest = @"
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-keyvault
  labels:
    app.kubernetes.io/part-of: cloudgames
spec:
  provider:
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: $kvUrl
      tenantId: $tenantId
      serviceAccountRef:
        name: $esoServiceAccount
        namespace: $esoNamespace
"@

kubectl delete clustersecretstore azure-keyvault 2>$null
Start-Sleep -Seconds 2

$tempFile = [System.IO.Path]::GetTempFileName()
$manifest | Out-File -FilePath $tempFile -Encoding utf8
kubectl apply -f $tempFile 2>&1 | Out-Null
Remove-Item $tempFile -Force

Write-Host "✅ ClusterSecretStore recreated" -ForegroundColor Green

Start-Sleep -Seconds 10

$store = kubectl get clustersecretstore azure-keyvault -o json 2>$null | ConvertFrom-Json
if ($store.status.conditions) {
    $readyCondition = $store.status.conditions | Where-Object { $_.type -eq "Ready" }
    if ($readyCondition.status -eq "True") {
        Write-Host "✅ Workload Identity configured - ClusterSecretStore READY!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  ClusterSecretStore status: $($readyCondition.reason)" -ForegroundColor Yellow
    }
}

# =============================================================================
# 8. Install Grafana Agent (Optional, inline)
# =============================================================================
if (-not $SkipGrafana) {
        Write-Host ""
        Write-Host "=== Step 8/9: Installing Grafana Agent ===" -ForegroundColor Yellow
        Write-Host ""

        $grafNamespace = "grafana-agent"
        $grafChartVersion = "0.42.0"

        helm repo add grafana https://grafana.github.io/helm-charts 2>$null
        helm repo update

        kubectl create namespace $grafNamespace --dry-run=client -o yaml | kubectl apply -f -

        $existingGraf = helm list -n $grafNamespace -q 2>$null | Where-Object { $_ -match "grafana-agent" }
        if ($existingGraf -and $Force) {
            Write-Host "🔄 Force requested: uninstalling existing Grafana Agent before reinstall" -ForegroundColor Yellow
            helm uninstall grafana-agent -n $grafNamespace --wait 2>$null
            Start-Sleep -Seconds 3
        }

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
            discovery.kubernetes "pods" { role = "pod" }
            discovery.kubernetes "nodes" { role = "node" }
            discovery.kubernetes "services" { role = "service" }
            prometheus.scrape "nodes" {
                targets    = discovery.kubernetes.nodes.targets
                forward_to = [prometheus.relabel.filter.receiver]
                bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
                tls_config { insecure_skip_verify = true }
            }
            prometheus.scrape "pods" {
                targets    = discovery.kubernetes.pods.targets
                forward_to = [prometheus.relabel.filter.receiver]
            }
            prometheus.relabel "filter" {
                rule { source_labels = ["__name__"], regex = "(up|container_.*|kube_.*|node_.*)", action = "keep" }
                forward_to = [prometheus.remote_write.grafana_cloud.receiver]
            }
            prometheus.remote_write "grafana_cloud" {
                endpoint { url = "http://localhost:9090/api/v1/write" }
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

        helm upgrade --install grafana-agent grafana/grafana-agent `
                --namespace $grafNamespace `
                --version $grafChartVersion `
                --values $valuesFile `
                --wait `
                --timeout 10m

        Remove-Item $valuesFile -Force -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️  Failed to install Grafana Agent (non-critical)" -ForegroundColor Yellow
        } else {
                Write-Host "✅ Grafana Agent installed" -ForegroundColor Green
        }
} else {
        Write-Host ""
        Write-Host "=== Step 8/9: Skipping Grafana Agent ===" -ForegroundColor Yellow
        Write-Host ""
}

# =============================================================================
# 9. Deploy Applications
# =============================================================================
if (-not $SkipDeploy) {
    Write-Host ""
    Write-Host "=== Step 9/9: Deploying Applications ===" -ForegroundColor Yellow
    Write-Host ""
    
    $overlayPath = Join-Path $k8sDir "overlays/$Environment"
    
    if (-not (Test-Path $overlayPath)) {
        Write-Host "❌ Overlay path not found: $overlayPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Applying Kustomize overlay: $Environment" -ForegroundColor Cyan
    kubectl apply -k $overlayPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to deploy applications" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Applications deployed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting for pods to be ready..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    Write-Host ""
    kubectl get pods -n cloudgames
} else {
    Write-Host ""
    Write-Host "=== Step 9/9: Skipping Application Deployment ===" -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# Summary
# =============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 NGINX Ingress IP: $nginxIP" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Verification Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Check pods status" -ForegroundColor Gray
Write-Host "  kubectl get pods -n cloudgames" -ForegroundColor White
Write-Host ""
Write-Host "  # Check External Secrets" -ForegroundColor Gray
Write-Host "  kubectl get externalsecrets -n cloudgames" -ForegroundColor White
Write-Host ""
Write-Host "  # Check Ingress" -ForegroundColor Gray
Write-Host "  kubectl get ingress -n cloudgames" -ForegroundColor White
Write-Host ""
Write-Host "  # Test health endpoints" -ForegroundColor Gray
Write-Host "  curl http://$nginxIP/health -H 'Host: games-api.cloudgames.local'" -ForegroundColor White
Write-Host "  curl http://$nginxIP/health -H 'Host: user-api.cloudgames.local'" -ForegroundColor White
Write-Host "  curl http://$nginxIP/health -H 'Host: payments-api.cloudgames.local'" -ForegroundColor White
Write-Host ""
Write-Host "📚 Documentation: infrastructure/kubernetes/scripts/prod/POST-TERRAFORM-SETUP.md" -ForegroundColor Cyan
Write-Host ""
