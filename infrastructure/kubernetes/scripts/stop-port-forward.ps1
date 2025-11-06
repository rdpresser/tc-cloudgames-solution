<#
.SYNOPSIS
  Para todos os port-forwards ativos do kubectl.
.DESCRIPTION
  Identifica e encerra todos os processos kubectl port-forward em execução.
  
.PARAMETER Service
  Opcional: Especifica qual serviço parar (argocd, grafana, ou all)
  
.EXAMPLE
  .\stop-port-forward.ps1
  .\stop-port-forward.ps1 argocd
  .\stop-port-forward.ps1 grafana
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("argocd", "grafana", "all")]
    [string]$Service = "all"
)

Write-Host "`n=== Stopping Port-Forwards ===" -ForegroundColor Cyan

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
