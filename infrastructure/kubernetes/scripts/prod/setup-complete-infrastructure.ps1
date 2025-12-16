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
# 2. Install NGINX Ingress
# =============================================================================
$nginxIP = $null

if (-not $SkipNginx) {
    Write-Host ""
    Write-Host "=== Step 2/9: Installing NGINX Ingress Controller ===" -ForegroundColor Yellow
    Write-Host ""

    $installArgs = @{
        ResourceGroup = $ResourceGroup
        ClusterName = $ClusterName
    }
    if ($Force) { $installArgs['Force'] = $true }

    & "$scriptDir\install-nginx-ingress.ps1" @installArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ NGINX Ingress installation failed" -ForegroundColor Red
        exit 1
    }
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
# 6. Install External Secrets Operator
# =============================================================================
Write-Host ""
Write-Host "=== Step 6/9: Installing External Secrets Operator ===" -ForegroundColor Yellow
Write-Host ""

$installArgs = @{
    ResourceGroup = $ResourceGroup
    ClusterName = $ClusterName
}
if ($Force) { $installArgs['Force'] = $true }

& "$scriptDir\install-external-secrets.ps1" @installArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ External Secrets Operator installation failed" -ForegroundColor Red
    exit 1
}

# =============================================================================
# 7. Setup Workload Identity for ESO
# =============================================================================
Write-Host ""
Write-Host "=== Step 7/9: Configuring Workload Identity ===" -ForegroundColor Yellow
Write-Host ""

$keyVaultName = if ($KeyVaultName) { $KeyVaultName } else { "tccloudgamesdevcr8nkv" }

& "$scriptDir\setup-eso-workload-identity.ps1" `
    -ResourceGroup $ResourceGroup `
    -ClusterName $ClusterName `
    -KeyVaultName $keyVaultName

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to configure Workload Identity" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Workload Identity configured" -ForegroundColor Green

# =============================================================================
# 8. Install Grafana Agent (Optional)
# =============================================================================
if (-not $SkipGrafana) {
    Write-Host ""
    Write-Host "=== Step 8/9: Installing Grafana Agent ===" -ForegroundColor Yellow
    Write-Host ""

    $installArgs = @{
        ResourceGroup = $ResourceGroup
        ClusterName = $ClusterName
    }
    if ($Force) { $installArgs['Force'] = $true }

    & "$scriptDir\install-grafana-agent.ps1" @installArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Failed to install Grafana Agent (non-critical)" -ForegroundColor Yellow
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
