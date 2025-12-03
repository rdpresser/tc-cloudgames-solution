<#
.SYNOPSIS
  Inicia port-forward para ArgoCD e/ou Grafana em modo background (detached).
.DESCRIPTION
  Script para facilitar acesso aos serviços do cluster k3d via port-forward.
  Executa em background sem prender o terminal.
  
  Serviços disponíveis:
  - argocd: http://localhost:8090 (redireciona para porta 443 do ArgoCD - HTTP Insecure)
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
function Test-PortForwardRunning($port, $serviceName) {
    # Primeiro verificar se a porta está em uso
    $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($connections.Count -eq 0) {
        return $false
    }
    
    # Verificar se é um kubectl port-forward para este serviço específico
    $kubectlProcs = Get-Process -Name kubectl -ErrorAction SilentlyContinue
    if (-not $kubectlProcs) {
        # Porta em uso mas não é kubectl - considerar como livre para nossos propósitos
        return $false
    }
    
    foreach ($proc in $kubectlProcs) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
            # Verificar se é port-forward E tem o serviço específico E usa a porta local correta
            if ($cmdLine -and 
                $cmdLine -like "*port-forward*" -and 
                $cmdLine -like "*svc/$serviceName*" -and 
                $cmdLine -match "(\d+):") {
                
                $localPort = $matches[1]
                if ($localPort -eq $port) {
                    Write-Host "   ℹ️  Encontrado processo existente: PID $($proc.Id)" -ForegroundColor Gray
                    return $true
                }
            }
        } catch {
            continue
        }
    }
    
    return $false
}

# Função para iniciar port-forward em background
function Start-PortForward($serviceName, $namespace, $port, $targetPort, $kubectlPath) {
    $portNumber = $port
    
    # Verificar se já existe port-forward para este serviço nesta porta
    if (Test-PortForwardRunning $portNumber $serviceName) {
        Write-Host "⚠️  Port-forward para $serviceName já está rodando na porta $portNumber" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host "🚀 Iniciando port-forward para $serviceName..." -ForegroundColor Cyan
    Write-Host "   📡 Acessível em: http://localhost:$port" -ForegroundColor Green
    Write-Host "   🔧 Usando: $kubectlPath" -ForegroundColor Gray
    
    # Iniciar processo em background usando caminho completo do kubectl
    $process = Start-Process -FilePath $kubectlPath `
        -ArgumentList "port-forward", "svc/$serviceName", "-n", "$namespace", "${port}:${targetPort}", "--address", "0.0.0.0" `
        -WindowStyle Hidden `
        -PassThru
    
    Write-Host "   ⏳ Processo iniciado: PID $($process.Id)" -ForegroundColor Gray
    
    # Aguardar um momento para garantir que o port-forward está ativo
    Start-Sleep -Seconds 3
    
    # Verificar se o processo ainda está rodando
    if ($process.HasExited) {
        Write-Host "❌ Falha ao iniciar port-forward para $serviceName" -ForegroundColor Red
        Write-Host "   O processo terminou imediatamente. Verifique se o serviço existe no cluster." -ForegroundColor Yellow
        return $null
    }
    
    # Validar se a porta realmente está escutando
    $portCheck = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if (-not $portCheck) {
        Write-Host "❌ Port-forward iniciou mas a porta $port não está escutando" -ForegroundColor Red
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
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

# Obter o caminho completo do kubectl
# Se for um shim do Chocolatey, usar o executável real
$kubectlCmd = Get-Command kubectl
$kubectlPath = $kubectlCmd.Source

# Verificar se é um shim do Chocolatey e usar o executável real
if ($kubectlPath -like "*chocolatey\bin\kubectl.exe") {
    $realPath = "C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe"
    if (Test-Path $realPath) {
        $kubectlPath = $realPath
        Write-Host "ℹ️  Usando kubectl real (não o shim): $kubectlPath" -ForegroundColor Gray
    }
}

Write-Host "`n=== Port-Forward Manager ===" -ForegroundColor Cyan
Write-Host "Modo: $Service`n" -ForegroundColor White

$processes = @()

# Iniciar port-forwards conforme solicitado
switch ($Service) {
    "argocd" {
        $proc = Start-PortForward "argocd-server" "argocd" 8090 443 $kubectlPath
        if ($proc) { $processes += $proc }
    }
    "grafana" {
        $proc = Start-PortForward "kube-prom-stack-grafana" "monitoring" 3000 80 $kubectlPath
        if ($proc) { $processes += $proc }
    }
    "all" {
        $proc1 = Start-PortForward "argocd-server" "argocd" 8090 443 $kubectlPath
        if ($proc1) { $processes += $proc1 }
        
        $proc2 = Start-PortForward "kube-prom-stack-grafana" "monitoring" 3000 80 $kubectlPath
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
    Write-Host "   🔐 ArgoCD:  http://localhost:8090" -ForegroundColor Green
}
if ($Service -eq "grafana" -or $Service -eq "all") {
    Write-Host "   📊 Grafana: http://localhost:3000" -ForegroundColor Green
}

Write-Host "`n💡 Para parar os port-forwards, execute: .\stop-port-forward.ps1`n" -ForegroundColor Yellow
