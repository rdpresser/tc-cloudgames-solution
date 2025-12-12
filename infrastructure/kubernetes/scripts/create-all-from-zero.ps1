<#
.SYNOPSIS
  Cria registry local, cluster k3d com 8GB, e instala ArgoCD, KEDA, kube-prom-stack (Prometheus+Grafana).
  Altera senha admin do Argo CD para Argo@123 e cria usuário Grafana rdpresser / rdpresser@123 com role Admin.
.DESCRIPTION
  Requisitos: k3d, kubectl, helm, docker, (argocd CLI opcional).
  Execute em PowerShell.
#>

# === Configurações ===
$clusterName = "dev"
$registryName = "localhost"
$registryPort = 5000
$serverCount = 1
$agentCount = 2
$memoryPerNode = "8g"
$agentMemory = "8g"
$argocdAdminNewPassword = "Argo@123"
$grafanaAdminPassword = "Grafana@123"
$grafanaNewUser = "rdpresser"
$grafanaNewUserEmail = "rodrigo.presser@gmail.com"
$grafanaNewUserPassword = "rdpresser@123"


# === 0) Verificando dependências ===
Write-Host "=== 0) Verificando dependências: kubectl, helm, k3d, docker ==="
foreach ($cmd in @("k3d","kubectl","helm","docker")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERRO: comando '$cmd' não encontrado no PATH. Instale antes de continuar." -ForegroundColor Red
        exit 1
    }
}

# === 0.1) Parar port-forwards existentes ===
Write-Host "=== 0.1) Parando port-forwards existentes para liberar portas ==="
if (Test-Path ".\stop-port-forward.ps1") {
    .\stop-port-forward.ps1 all
} else {
    Write-Host "Aviso: stop-port-forward.ps1 não encontrado. Certifique-se de que as portas 8090 e 3000 estão livres." -ForegroundColor Yellow
}

# === 1) Criar registry se necessário ===
Write-Host "=== 1) Verificando registry local ($registryName`:$registryPort) ==="
$regList = k3d registry list
if ($regList -notmatch $registryName) {
    Write-Host "Criando registry $registryName`:$registryPort"
    k3d registry create $registryName --port $registryPort
} else { 
    Write-Host "Registry $registryName já existe. Pulando." 
}

# === 2) Deletar cluster se existir ===
Write-Host "=== 2) Deletando cluster $clusterName (se existir) ==="
k3d cluster list | Select-String -Pattern "^$clusterName\s" | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Cluster $clusterName existe. Deletando..."
    k3d cluster delete $clusterName
} else {
    Write-Host "Cluster $clusterName não existe. Pulando delete."
}

# === 3) Criar cluster com recursos configurados ===
Write-Host "=== 3) Criando cluster $clusterName com $memoryPerNode por node..."
k3d cluster create $clusterName --servers $serverCount --agents $agentCount `
  --port "80:80@loadbalancer" --port "443:443@loadbalancer" `
  --servers-memory $memoryPerNode --agents-memory $agentMemory `
  --registry-use "$registryName`:$registryPort"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Falha ao criar o cluster. Saindo." -ForegroundColor Red
    exit 1
}

Write-Host "Aguardando cluster ficar pronto..." -ForegroundColor Cyan
Start-Sleep -Seconds 15

# Ajusta contexto kubectl
kubectl config use-context "k3d-$clusterName"

# Fix para WSL2: substituir host.docker.internal por 127.0.0.1
Write-Host "Ajustando kubeconfig para usar 127.0.0.1..." -ForegroundColor Cyan
$serverUrl = kubectl config view -o json | ConvertFrom-Json | 
    ForEach-Object { $_.clusters | Where-Object { $_.name -eq "k3d-$clusterName" } } | 
    ForEach-Object { $_.cluster.server }

if ($serverUrl -match "host.docker.internal:(\d+)") {
    $port = $matches[1]
    kubectl config set-cluster "k3d-$clusterName" --server="https://127.0.0.1:$port" | Out-Null
    Write-Host "✅ Kubeconfig ajustado para https://127.0.0.1:$port" -ForegroundColor Green
}

# Validar conectividade com API do cluster (retry com timeout)
Write-Host "Validando conectividade com API do Kubernetes..." -ForegroundColor Cyan
$apiReady = $false
for ($i=0; $i -lt 30; $i++) {
    try {
        kubectl cluster-info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $apiReady = $true
            Write-Host "✅ API do Kubernetes acessível" -ForegroundColor Green
            break
        }
    } catch {}
    Write-Host "   Tentativa $($i+1)/30: API ainda não está pronta..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

if (-not $apiReady) {
    Write-Host "❌ ERRO: API do Kubernetes não respondeu após 2.5 minutos" -ForegroundColor Red
    Write-Host "   Tente os seguintes passos:" -ForegroundColor Yellow
    Write-Host "   1. Reinicie o Docker Desktop" -ForegroundColor Yellow
    Write-Host "   2. Execute: k3d cluster delete $clusterName" -ForegroundColor Yellow
    Write-Host "   3. Execute este script novamente" -ForegroundColor Yellow
    exit 1
}

# === 4) Criar namespaces básicos ===
Write-Host "=== 4) Criando namespaces: argocd, monitoring, keda, users ==="
foreach ($ns in @("argocd","monitoring","keda","users")) {
    kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply --validate=false -f -
}

# === 5) Instalar Argo CD via Helm ===
Write-Host "=== 5) Instalando Argo CD ==="

# Validar cluster antes de instalar
kubectl get nodes | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Cluster não está acessível. Abortando." -ForegroundColor Red
    exit 1
}

helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd `
    --create-namespace `
    --set server.service.type=LoadBalancer `
    --set server.ingress.enabled=false `
    --set configs.params."server\.insecure"=true

Write-Host "Aguardando pods do ArgoCD estarem prontos..."
Start-Sleep -Seconds 10

# === 6) Instalar KEDA ===
Write-Host "=== 6) Instalando KEDA ==="

# Validar cluster antes de instalar
kubectl get nodes | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Cluster não está acessível. Abortando." -ForegroundColor Red
    exit 1
}

helm repo add kedacore https://kedacore.github.io/charts 2>$null
helm repo update
helm upgrade --install keda kedacore/keda -n keda --create-namespace

# === 7) Instalar Prometheus + Grafana (kube-prometheus-stack) ===
Write-Host "=== 7) Instalando kube-prometheus-stack (Prometheus + Grafana) ==="

# Validar cluster antes de instalar
kubectl get nodes | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Cluster não está acessível. Abortando." -ForegroundColor Red
    exit 1
}

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null
helm repo add grafana https://grafana.github.io/helm-charts 2>$null
helm repo update

helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring `
  --create-namespace `
  --set grafana.enabled=true `
  --set grafana.adminPassword="$grafanaAdminPassword" `
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

Write-Host "Aguardando Grafana ficar pronto..."
Start-Sleep -Seconds 10
# aguardar grafana
$ok = $false
for ($i=0; $i -lt 40; $i++) {
    $pods = kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana --no-headers
    if ($pods -match "Running") { $ok = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $ok) { Write-Host "Aviso: Grafana demorou pra subir." -ForegroundColor Yellow }

# === 8) Recuperar senhas iniciais ===
Write-Host "=== 8) Recuperando senhas iniciais ==="
$argocdInitialPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
Write-Host "ArgoCD initial admin password: $argocdInitialPassword"

# Grafana admin password (from secret or from value we set)
try {
    $grafanaSecret = kubectl -n monitoring get secret kube-prom-stack-grafana -o jsonpath="{.data.admin-password}" 2>$null
    if ($grafanaSecret) {
        $grafanaAdminCurrent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($grafanaSecret))
    } else {
        $grafanaAdminCurrent = $grafanaAdminPassword
    }
} catch {
    $grafanaAdminCurrent = $grafanaAdminPassword
}
Write-Host "Grafana admin password: $grafanaAdminCurrent"

# === 9) Alterar senha do Argo CD ===
Write-Host "=== 9) Ajustando senha do ArgoCD para $argocdAdminNewPassword ==="
# Port-forward argocd-server localmente
Write-Host "Fazendo port-forward do argocd-server para 8090 (background)..."
$pfArgocd = Start-Process -FilePath kubectl -ArgumentList "port-forward svc/argocd-server -n argocd 8090:443 --address 0.0.0.0" -WindowStyle Hidden -PassThru
Write-Host "Aguardando port-forward ficar disponível..."
Start-Sleep -Seconds 8

# Verificar se port-forward está acessível
$pfReady = $false
for ($i=0; $i -lt 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8090" -Method Head -TimeoutSec 2 -ErrorAction Stop
        $pfReady = $true
        Write-Host "✅ Port-forward acessível via localhost:8090" -ForegroundColor Green
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $pfReady) {
    Write-Host "⚠️  Aviso: Port-forward pode não estar totalmente pronto. Tentando mesmo assim..." -ForegroundColor Yellow
}

# Alterar senha via API REST (mais confiável que CLI)
$loginOk = $false
try {
    # Obter token de sessão
    $loginBody = @{ username = "admin"; password = $argocdInitialPassword } | ConvertTo-Json
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:8090/api/v1/session" -Method Post -Body $loginBody -ContentType "application/json" -ErrorAction Stop
    $token = $loginResponse.token
    
    # Atualizar senha
    $updateBody = @{ currentPassword = $argocdInitialPassword; newPassword = $argocdAdminNewPassword } | ConvertTo-Json
    $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
    Invoke-RestMethod -Uri "http://localhost:8090/api/v1/account/password" -Method Put -Headers $headers -Body $updateBody -ErrorAction Stop | Out-Null
    
    $loginOk = $true
    Write-Host "✅ Senha do ArgoCD alterada com sucesso para: $argocdAdminNewPassword" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Falha ao alterar senha do ArgoCD: $_" -ForegroundColor Yellow
    Write-Host "   Você pode alterar manualmente via UI em http://localhost:8090" -ForegroundColor Yellow
    $loginOk = $false
}
# kill port-forward
Stop-Process -Id $pfArgocd.Id -ErrorAction SilentlyContinue

# === 10) Criar usuário Grafana via API ===
Write-Host "=== 10) Criando usuário Grafana $grafanaNewUser ==="
# Port-forward grafana svc para localhost:3000
$pfGraf = Start-Process -FilePath kubectl -ArgumentList "port-forward svc/kube-prom-stack-grafana -n monitoring 3000:80 --address 0.0.0.0" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 5
$grafanaApi = "http://localhost:3000"
# create user
$createJson = @{ name = "Rodrigo"; email = $grafanaNewUserEmail; login = $grafanaNewUser; password = $grafanaNewUserPassword } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Post -Uri "$grafanaApi/api/admin/users" -Body $createJson -ContentType "application/json" -Credential (New-Object System.Management.Automation.PSCredential("admin",(ConvertTo-SecureString $grafanaAdminCurrent -AsPlainText -Force))) -AllowUnencryptedAuthentication -ErrorAction Stop | Out-Null
    Write-Host "Usuário $grafanaNewUser criado em Grafana."
} catch { 
    Write-Host "Falha ao criar usuário Grafana (pode já existir) - $_" -ForegroundColor Yellow 
}

# Adicionar usuário ao org como Admin (orgId 1 normalmente)
try {
    $addJson = @{ loginOrEmail = $grafanaNewUser; role = "Admin" } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$grafanaApi/api/orgs/1/users" -Body $addJson -ContentType "application/json" -Credential (New-Object System.Management.Automation.PSCredential("admin",(ConvertTo-SecureString $grafanaAdminCurrent -AsPlainText -Force))) -AllowUnencryptedAuthentication -ErrorAction Stop
    Write-Host "Usuário $grafanaNewUser promovido a Admin da org."
} catch { 
    Write-Host "Falha ao promover usuário (talvez já seja admin) - $_" -ForegroundColor Yellow 
}

# kill grafana port-forward
Stop-Process -Id $pfGraf.Id -ErrorAction SilentlyContinue

Write-Host "=== Finalizado: ambiente criado. Resumo ==="
Write-Host "ArgoCD initial (original): $argocdInitialPassword"
Write-Host "ArgoCD admin senha atual: $argocdAdminNewPassword"
Write-Host "Grafana admin senha atual: $grafanaAdminCurrent"
Write-Host "Grafana user criado: $grafanaNewUser / $grafanaNewUserPassword"
