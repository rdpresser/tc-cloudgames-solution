<#
.SYNOPSIS
  Inicia o cluster k3d "dev" após reiniciar o computador.
.DESCRIPTION
  Este script verifica se o cluster k3d existe e o inicia se estiver parado.
  Use este script após reiniciar o computador para reativar o cluster.
  
  O que este script faz:
  1. Verifica se Docker está rodando
  2. Lista clusters k3d existentes
  3. Inicia o cluster "dev" se ele existir
  4. Configura o contexto kubectl correto
  5. Aguarda os pods principais ficarem prontos
  
.EXAMPLE
  .\start-cluster.ps1
#>

$clusterName = "dev"

Write-Host "`n=== Iniciando Cluster K3D ===" -ForegroundColor Cyan
Write-Host ""

# 1) Verificar se Docker está rodando
Write-Host "🐳 Verificando se Docker está rodando..." -ForegroundColor Cyan
try {
    docker ps | Out-Null
    Write-Host "✅ Docker está ativo" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker não está rodando. Inicie o Docker Desktop primeiro!" -ForegroundColor Red
    Write-Host "   Aguarde o Docker Desktop iniciar completamente antes de continuar." -ForegroundColor Yellow
    exit 1
}

# 2) Verificar se o cluster existe
Write-Host "`n📋 Verificando clusters k3d existentes..." -ForegroundColor Cyan
$clusterList = k3d cluster list 2>&1 | Out-String

if ($clusterList -notmatch $clusterName) {
    Write-Host "❌ Cluster '$clusterName' não encontrado!" -ForegroundColor Red
    Write-Host "   Execute .\create-all-from-zero.ps1 para criar o cluster primeiro." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Cluster '$clusterName' encontrado" -ForegroundColor Green

# 3) Verificar se containers do cluster estão rodando
Write-Host "`n🔍 Verificando status dos containers..." -ForegroundColor Cyan
$containers = docker ps -a --filter "name=k3d-$clusterName" --format "{{.Names}}\t{{.Status}}"

if (-not $containers) {
    Write-Host "❌ Nenhum container encontrado para o cluster '$clusterName'" -ForegroundColor Red
    Write-Host "   O cluster pode ter sido deletado. Execute .\create-all-from-zero.ps1" -ForegroundColor Yellow
    exit 1
}

# Verificar se algum container está parado
$stoppedContainers = $containers | Where-Object { $_ -match "Exited" }

if ($stoppedContainers) {
    Write-Host "⚠️  Containers do cluster estão parados. Iniciando..." -ForegroundColor Yellow
    k3d cluster start $clusterName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Falha ao iniciar o cluster!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Cluster iniciado com sucesso" -ForegroundColor Green
    Start-Sleep -Seconds 5
} else {
    Write-Host "✅ Cluster já está rodando" -ForegroundColor Green
}

# 4) Configurar contexto kubectl
Write-Host "`n⚙️  Configurando contexto kubectl..." -ForegroundColor Cyan
kubectl config use-context "k3d-$clusterName" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Falha ao configurar contexto kubectl!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Contexto kubectl configurado: k3d-$clusterName" -ForegroundColor Green

# 5) Aguardar pods principais ficarem prontos
Write-Host "`n⏳ Aguardando pods principais ficarem prontos..." -ForegroundColor Cyan
Write-Host "   (Isso pode levar alguns minutos após reboot)" -ForegroundColor Gray

$namespaces = @("argocd", "monitoring", "keda")
$ready = $true

foreach ($ns in $namespaces) {
    Write-Host "   Verificando namespace: $ns" -ForegroundColor Gray
    
    $attempts = 0
    $maxAttempts = 30
    
    while ($attempts -lt $maxAttempts) {
        $pods = kubectl -n $ns get pods --no-headers 2>$null
        
        if ($pods) {
            $notReady = $pods | Where-Object { $_ -notmatch "Running|Completed" }
            
            if (-not $notReady) {
                Write-Host "   ✅ ${ns}: Todos os pods prontos" -ForegroundColor Green
                break
            }
        }
        
        $attempts++
        Start-Sleep -Seconds 5
    }
    
    if ($attempts -eq $maxAttempts) {
        Write-Host "   ⚠️  ${ns}: Alguns pods ainda não estão prontos (timeout)" -ForegroundColor Yellow
        $ready = $false
    }
}

# 6) Resumo
Write-Host "`n=== Resumo ===" -ForegroundColor Cyan
Write-Host "Cluster:  k3d-$clusterName" -ForegroundColor White
Write-Host "Status:   " -NoNewline
if ($ready) {
    Write-Host "✅ Pronto" -ForegroundColor Green
} else {
    Write-Host "⚠️  Parcialmente pronto (alguns pods ainda inicializando)" -ForegroundColor Yellow
}

Write-Host "`n💡 Próximos passos:" -ForegroundColor Cyan
Write-Host "   1. Execute: .\port-forward.ps1 all" -ForegroundColor White
Write-Host "   2. Acesse ArgoCD: http://localhost:8090" -ForegroundColor White
Write-Host "   3. Acesse Grafana: http://localhost:3000" -ForegroundColor White
Write-Host ""

