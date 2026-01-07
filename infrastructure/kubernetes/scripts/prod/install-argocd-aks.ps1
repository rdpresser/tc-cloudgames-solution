<#
.SYNOPSIS
  Installs ArgoCD on Azure AKS cluster using YAML manifests.
  
.DESCRIPTION
  Installs ArgoCD via official YAML manifests from GitHub.
  Configures LoadBalancer, sets admin password, and enables for bootstrap.
  
.PARAMETER ResourceGroup
  Azure Resource Group name.
  
.PARAMETER ClusterName
  AKS cluster name.
  
.PARAMETER Namespace
  Kubernetes namespace for ArgoCD. Default: argocd
  
.PARAMETER AdminPassword
  ArgoCD admin password. Default: Argo@AKS123!
  
.EXAMPLE
  .\install-argocd-aks.ps1 -ResourceGroup "rg" -ClusterName "aks"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "argocd",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminPassword = "Argo@AKS123!"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Installing ArgoCD (YAML) for Azure AKS                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Namespace: $Namespace" -ForegroundColor Gray
Write-Host "Password: $('*' * $AdminPassword.Length)" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# Check if already installed
# =============================================================================
Write-Host "Checking for existing installation..." -ForegroundColor Yellow
$existing = kubectl get namespace $Namespace 2>$null
if ($existing) {
    $serverPods = kubectl get pods -n $Namespace --selector=app.kubernetes.io/name=argocd-server --no-headers 2>$null
    if ($serverPods) {
        Write-Host "✅ ArgoCD already installed in namespace '$Namespace'" -ForegroundColor Green
        exit 0
    }
}

# =============================================================================
# Create namespace
# =============================================================================
Write-Host "Creating namespace '$Namespace'..." -ForegroundColor Yellow
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create namespace" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Namespace created" -ForegroundColor Green

# =============================================================================
# Install ArgoCD
# =============================================================================
Write-Host "Installing ArgoCD manifests..." -ForegroundColor Yellow
$manifestUrl = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

kubectl apply -n $Namespace -f $manifestUrl 2>&1 | ForEach-Object {
    if ($_ -match "created|configured|unchanged") {
        Write-Host "  ✅ $_" -ForegroundColor Green
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to apply manifests" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Wait for deployments
# =============================================================================
Write-Host "Waiting for ArgoCD components..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n $Namespace 2>$null
kubectl wait --for=condition=available --timeout=120s deployment/argocd-repo-server -n $Namespace 2>$null
Write-Host "✅ Components ready" -ForegroundColor Green

# =============================================================================
# Set password
# =============================================================================
Write-Host "Setting admin password..." -ForegroundColor Yellow

# Method 1: Using argocd CLI (if available)
$argoCdExe = Get-Command argocd -ErrorAction SilentlyContinue
if ($argoCdExe) {
    Write-Host "  Using argocd CLI to update password..." -ForegroundColor Gray
    
    # Get initial password
    $initialPwd = kubectl get secret argocd-initial-admin-secret -n $Namespace -o jsonpath='{.data.password}' 2>$null | ForEach-Object {
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
    }
    
    if ($initialPwd) {
        # Wait for server to be ready
        Start-Sleep -Seconds 10
        
        # Get server pod
        $serverPod = kubectl get pod -n $Namespace -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>$null
        
        if ($serverPod) {
            # Update password using argocd CLI inside the pod
            $updateCmd = "argocd account update-password --current-password '$initialPwd' --new-password '$AdminPassword' --account admin --plaintext"
            kubectl exec -n $Namespace $serverPod -- sh -c $updateCmd 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Password updated via argocd CLI" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Could not update password via CLI, trying manual method..." -ForegroundColor Yellow
            }
        }
    }
}

# Method 2: Generate bcrypt hash and patch secret
$podName = "bcrypt-$(Get-Random -Maximum 9999)"
$bcryptPod = @"
apiVersion: v1
kind: Pod
metadata:
  name: $podName
  namespace: $Namespace
spec:
  containers:
  - name: htpasswd
    image: httpd:2.4-alpine
    command: ["sh", "-c", "htpasswd -nbBC 10 admin '$AdminPassword' | cut -d: -f2"]
  restartPolicy: Never
"@

Write-Host "  Generating bcrypt hash..." -ForegroundColor Gray
$bcryptPod | kubectl apply -f - 2>$null | Out-Null

# Wait for pod to complete
$retries = 0
while ($retries -lt 15) {
    $podStatus = kubectl get pod $podName -n $Namespace -o jsonpath='{.status.phase}' 2>$null
    if ($podStatus -eq "Succeeded" -or $podStatus -eq "Failed") {
        break
    }
    Start-Sleep -Seconds 2
    $retries++
}

$hash = kubectl logs $podName -n $Namespace 2>$null | Select-Object -First 1
kubectl delete pod $podName -n $Namespace --ignore-not-found 2>$null | Out-Null

if ($hash -and $hash.StartsWith('$2')) {
    Write-Host "  Patching argocd-secret..." -ForegroundColor Gray
    $hashB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($hash))
    kubectl patch secret argocd-secret -n $Namespace -p "{`"data`": {`"admin.password`": `"$hashB64`", `"admin.passwordMtime`": `"$(([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")))))`"}}" 2>$null
    
    # Restart argocd-server to pick up new password
    kubectl rollout restart deployment argocd-server -n $Namespace 2>$null | Out-Null
    kubectl rollout status deployment argocd-server -n $Namespace --timeout=60s 2>$null | Out-Null
    
    Write-Host "✅ Password set and server restarted" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not generate bcrypt hash" -ForegroundColor Yellow
    Write-Host "⚠️  Use initial admin password from secret: kubectl get secret argocd-initial-admin-secret -n $Namespace" -ForegroundColor Yellow
}

# =============================================================================
# Configure LoadBalancer
# =============================================================================
Write-Host "Configuring LoadBalancer service..." -ForegroundColor Yellow
kubectl patch svc argocd-server -n $Namespace -p '{"spec": {"type": "LoadBalancer"}}' 2>$null
Write-Host "✅ Service configured" -ForegroundColor Green

# =============================================================================
# Get access info
# =============================================================================
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        ✅ ArgoCD Installation Complete!                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Waiting for LoadBalancer IP (up to 30 seconds)..." -ForegroundColor Yellow

$ip = $null
for ($i = 0; $i -lt 10; $i++) {
    $ip = kubectl get svc argocd-server -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($ip) { break }
    Start-Sleep -Seconds 3
}

if ($ip) {
    Write-Host ""
    Write-Host "🌐 URL      : http://$ip" -ForegroundColor Cyan
    Write-Host "👤 Username : admin" -ForegroundColor White
    Write-Host "🔐 Password : $AdminPassword" -ForegroundColor Green
} else {
    Write-Host "⏳ IP pending..." -ForegroundColor Yellow
    Write-Host "Username: admin | Password: $AdminPassword" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next: .\aks-manager.ps1 bootstrap" -ForegroundColor Cyan
Write-Host ""

exit 0
