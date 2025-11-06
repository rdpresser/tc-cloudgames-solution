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
$registryName = "k3d-registry.local"
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

# Ajusta contexto kubectl
kubectl config use-context "k3d-$clusterName"

# === 4) Criar namespaces básicos ===
Write-Host "=== 4) Criando namespaces: argocd, monitoring, keda, users ==="
foreach ($ns in @("argocd","monitoring","keda","users")) {
    kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
}

# === 5) Instalar Argo CD via Helm ===
Write-Host "=== 5) Instalando Argo CD ==="
helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd `
    --create-namespace `
    --set server.service.type=LoadBalancer `
    --set server.ingress.enabled=false

Write-Host "Aguardando pods do ArgoCD estarem prontos..."
Start-Sleep -Seconds 10

# === 6) Instalar KEDA ===
Write-Host "=== 6) Instalando KEDA ==="
helm repo add kedacore https://kedacore.github.io/charts 2>$null
helm repo update
helm upgrade --install keda kedacore/keda -n keda --create-namespace

# === 7) Instalar Prometheus + Grafana (kube-prometheus-stack) ===
Write-Host "=== 7) Instalando kube-prometheus-stack (Prometheus + Grafana) ==="
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
# Garantir que argocd CLI exista (instalar via choco se necessário)
if (-not (Get-Command argocd -ErrorAction SilentlyContinue)) {
    Write-Host "argocd CLI não encontrado. Instalando via choco (requer admin)..."
    choco install argocd -y
    RefreshEnv
}
# Port-forward argocd-server localmente
Write-Host "Fazendo port-forward do argocd-server para 8080 (background)..."
$pfArgocd = Start-Process -FilePath kubectl -ArgumentList "port-forward svc/argocd-server -n argocd 8080:443" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 5

# Login com senha inicial
$loginOk = $false
try {
    & argocd login localhost:8080 --insecure --username admin --password $argocdInitialPassword | Out-Null
    & argocd account update-password --account admin --current-password $argocdInitialPassword --new-password $argocdAdminNewPassword | Out-Null
    $loginOk = $true
} catch {
    Write-Host "Falha ao alterar senha do ArgoCD via argocd CLI. Tente manualmente." -ForegroundColor Yellow
    $loginOk = $false
}
# kill port-forward
Stop-Process -Id $pfArgocd.Id -ErrorAction SilentlyContinue
if ($loginOk) { Write-Host "Senha do ArgoCD alterada com sucesso para: $argocdAdminNewPassword" -ForegroundColor Green }

# === 10) Criar usuário Grafana via API ===
Write-Host "=== 10) Criando usuário Grafana $grafanaNewUser ==="
# Port-forward grafana svc para localhost:3000
$pfGraf = Start-Process -FilePath kubectl -ArgumentList "port-forward svc/kube-prom-stack-grafana -n monitoring 3000:80" -WindowStyle Hidden -PassThru
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
