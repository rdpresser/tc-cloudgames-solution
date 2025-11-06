<#
.SYNOPSIS
  Lista todos os port-forwards ativos e suas portas.
.DESCRIPTION
  Mostra informações sobre processos kubectl port-forward em execução,
  incluindo PID, portas e tempo de execução.
.EXAMPLE
  .\list-port-forward.ps1
#>

Write-Host "`n=== Port-Forwards Ativos ===" -ForegroundColor Cyan
Write-Host ""

# Buscar processos kubectl com port-forward
$kubectlProcesses = Get-Process -Name kubectl -ErrorAction SilentlyContinue

if (-not $kubectlProcesses) {
    Write-Host "ℹ️  Nenhum port-forward ativo" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

$found = $false

foreach ($proc in $kubectlProcesses) {
    try {
        # Tentar obter a linha de comando do processo
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
        
        # Verificar se é um port-forward
        if ($cmdLine -like "*port-forward*") {
            $found = $true
            
            # Extrair informações
            $service = "Unknown"
            $port = "Unknown"
            
            if ($cmdLine -match "svc/([^\s]+)") {
                $service = $matches[1]
            }
            
            if ($cmdLine -match "(\d+):\d+") {
                $port = $matches[1]
            }
            
            # Calcular tempo de execução
            $uptime = (Get-Date) - $proc.StartTime
            $uptimeStr = "{0:hh\:mm\:ss}" -f $uptime
            
            Write-Host "🔗 Port-Forward Ativo:" -ForegroundColor Green
            Write-Host "   Serviço: $service" -ForegroundColor White
            Write-Host "   Porta:   http://localhost:$port" -ForegroundColor Cyan
            Write-Host "   PID:     $($proc.Id)" -ForegroundColor Gray
            Write-Host "   Uptime:  $uptimeStr" -ForegroundColor Gray
            Write-Host ""
        }
    } catch {
        # Ignorar erros ao acessar informações do processo
        continue
    }
}

if (-not $found) {
    Write-Host "ℹ️  Nenhum port-forward ativo" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "💡 Use '.\stop-port-forward.ps1' para parar os port-forwards" -ForegroundColor Yellow
Write-Host ""
