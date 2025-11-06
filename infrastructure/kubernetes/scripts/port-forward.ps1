<#
.SYNOPSIS
  Inicia port-forward para ArgoCD e/ou Grafana em modo background (detached).
.DESCRIPTION
  Script para facilitar acesso aos serviços do cluster k3d via port-forward.
  Executa em background sem prender o terminal.
  
  Serviços disponíveis:
  - argocd: http://localhost:8080 (redireciona para porta 443 do ArgoCD)
  - grafana: http://localhost:3000 (redireciona para porta 80 do Grafana)
  - all: Inicia ambos os port-forwards
  
.PARAMETER Service
  Serviço para port-forward: argocd, grafana, ou all
  
.EXAMPLE
  .\port-forward.ps1 argocd
  .\port-forward.ps1 grafana
  .\port-forward.ps1 all
  .\port-forward.ps1 -Service all
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("argocd", "grafana", "all")]
    [string]$Service = "all"
)

# Função para verificar se port-forward já está rodando
function Test-PortForwardRunning($port) {
    $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    return $connections.Count -gt 0
}

# Função para iniciar port-forward em background
function Start-PortForward($serviceName, $namespace, $port, $targetPort) {
    $portNumber = $port
    
    # Verificar se já existe port-forward nesta porta
    if (Test-PortForwardRunning $portNumber) {
        Write-Host "⚠️  Port-forward para $serviceName já está rodando na porta $portNumber" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host "🚀 Iniciando port-forward para $serviceName..." -ForegroundColor Cyan
    Write-Host "   📡 Acessível em: http://localhost:$port" -ForegroundColor Green
    
    # Iniciar processo em background
    $process = Start-Process -FilePath "kubectl" `
        -ArgumentList "port-forward", "svc/$serviceName", "-n", "$namespace", "${port}:${targetPort}" `
        -WindowStyle Hidden `
        -PassThru
    
    # Aguardar um momento para garantir que o port-forward está ativo
    Start-Sleep -Seconds 2
    
    # Verificar se o processo ainda está rodando
    if ($process.HasExited) {
        Write-Host "❌ Falha ao iniciar port-forward para $serviceName" -ForegroundColor Red
        return $null
    }
    
    Write-Host "✅ Port-forward para $serviceName iniciado (PID: $($process.Id))" -ForegroundColor Green
    return $process
}

# Verificar se kubectl está disponível
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERRO: kubectl não encontrado no PATH" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Port-Forward Manager ===" -ForegroundColor Cyan
Write-Host "Modo: $Service`n" -ForegroundColor White

$processes = @()

# Iniciar port-forwards conforme solicitado
switch ($Service) {
    "argocd" {
        $proc = Start-PortForward "argocd-server" "argocd" 8080 443
        if ($proc) { $processes += $proc }
    }
    "grafana" {
        $proc = Start-PortForward "kube-prom-stack-grafana" "monitoring" 3000 80
        if ($proc) { $processes += $proc }
    }
    "all" {
        $proc1 = Start-PortForward "argocd-server" "argocd" 8080 443
        if ($proc1) { $processes += $proc1 }
        
        $proc2 = Start-PortForward "kube-prom-stack-grafana" "monitoring" 3000 80
        if ($proc2) { $processes += $proc2 }
    }
}

if ($processes.Count -eq 0) {
    Write-Host "`n⚠️  Nenhum port-forward foi iniciado" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n" -NoNewline
Write-Host "📌 Port-forwards ativos:" -ForegroundColor Cyan
if ($Service -eq "argocd" -or $Service -eq "all") {
    Write-Host "   🔐 ArgoCD:  http://localhost:8080" -ForegroundColor Green
}
if ($Service -eq "grafana" -or $Service -eq "all") {
    Write-Host "   📊 Grafana: http://localhost:3000" -ForegroundColor Green
}

Write-Host "`n💡 Para parar os port-forwards, execute: .\stop-port-forward.ps1`n" -ForegroundColor Yellow
