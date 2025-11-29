<#
.SYNOPSIS
  Para port-forwards ativos do kubectl.
.DESCRIPTION
  Identifica e encerra processos kubectl port-forward em execução.
  Permite encerrar por nome do serviço ou por PID específico.
  
.PARAMETER Service
  Opcional: Especifica qual serviço parar (argocd, grafana, ou all). Default: all.
  
.PARAMETER Id
  Opcional: PID específico para matar (útil para processos travados/zumbis).

.EXAMPLE
  .\stop-port-forward.ps1
  .\stop-port-forward.ps1 argocd
  .\stop-port-forward.ps1 -Id 12345
#>

[CmdletBinding(DefaultParameterSetName="ByService")]
param(
    [Parameter(ParameterSetName="ByService", Position = 0)]
    [ValidateSet("argocd", "grafana", "all")]
    [string]$Service = "all",

    [Parameter(ParameterSetName="ById", Mandatory=$true)]
    [int]$Id
)

Write-Host "`n=== Stopping Port-Forwards ===" -ForegroundColor Cyan

if ($PSCmdlet.ParameterSetName -eq "ById") {
    try {
        $proc = Get-Process -Id $Id -ErrorAction Stop
        Write-Host "🛑 Parando processo PID: $($proc.Id) ($($proc.ProcessName))..." -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force
        Write-Host "✅ Processo encerrado com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "❌ Erro ao parar PID ${Id}: $_" -ForegroundColor Red
    }
    exit
}

# Buscar processos kubectl com port-forward
$kubectlProcesses = Get-Process -Name kubectl -ErrorAction SilentlyContinue

if (-not $kubectlProcesses) {
    Write-Host "✅ Nenhum port-forward ativo encontrado" -ForegroundColor Green
    exit 0
}

$stopped = 0

foreach ($proc in $kubectlProcesses) {
    try {
        # Tentar obter a linha de comando do processo
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
        
        # Verificar se é um port-forward
        if ($cmdLine -like "*port-forward*") {
            $shouldStop = $false
            
            switch ($Service) {
                "argocd" {
                    if ($cmdLine -like "*argocd-server*") {
                        $shouldStop = $true
                    }
                }
                "grafana" {
                    if ($cmdLine -like "*grafana*") {
                        $shouldStop = $true
                    }
                }
                "all" {
                    $shouldStop = $true
                }
            }
            
            if ($shouldStop) {
                Write-Host "🛑 Parando port-forward (PID: $($proc.Id))..." -ForegroundColor Yellow
                Stop-Process -Id $proc.Id -Force
                $stopped++
            }
        }
    } catch {
        # Ignorar erros ao acessar informações do processo
        continue
    }
}

if ($stopped -gt 0) {
    Write-Host "✅ $stopped port-forward(s) parado(s)" -ForegroundColor Green
} else {
    Write-Host "ℹ️  Nenhum port-forward correspondente encontrado" -ForegroundColor Cyan
}

Write-Host ""
