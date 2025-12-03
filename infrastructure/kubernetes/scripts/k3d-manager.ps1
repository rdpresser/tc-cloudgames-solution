<#
.SYNOPSIS
  K3D Manager - Orquestrador central para gerenciamento do cluster k3d local.
  
.DESCRIPTION
  Script principal que centraliza e facilita o acesso a todos os scripts de gerenciamento
  do cluster k3d. Fornece um menu interativo e suporte a linha de comando.
  
.PARAMETER Command
  Comando a ser executado. Use --help para ver lista completa.
  
.PARAMETER Service
  Serviço específico (usado com port-forward/stop-port-forward).
  
.PARAMETER Id
  PID específico (usado com stop-port-forward).
  
.EXAMPLE
  .\k3d-manager.ps1
  # Abre menu interativo
  
.EXAMPLE
  .\k3d-manager.ps1 --help
  # Mostra todos os comandos disponíveis
  
.EXAMPLE
  .\k3d-manager.ps1 create
  # Cria cluster do zero
  
.EXAMPLE
  .\k3d-manager.ps1 port-forward argocd
  # Inicia port-forward apenas para ArgoCD
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,
    
    [Parameter(Position = 1)]
    [string]$Service,
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$RemainingArgs
)

# Cores e formatação
$script:Colors = @{
    Title = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
    Muted = "Gray"
}

function Show-Header {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
    Write-Host "║          🚀 K3D Cluster Manager v1.0                      ║" -ForegroundColor $Colors.Title
    Write-Host "║          Gerenciador de Cluster Local Kubernetes          ║" -ForegroundColor $Colors.Title
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
    Write-Host ""
}

function Show-Help {
    Show-Header
    
    Write-Host "📖 COMANDOS DISPONÍVEIS:" -ForegroundColor $Colors.Title
    Write-Host ""
    
    Write-Host "  🔧 GERENCIAMENTO DE CLUSTER:" -ForegroundColor $Colors.Info
    Write-Host "    create              " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Cria/recria cluster completo do zero" -ForegroundColor $Colors.Muted
    Write-Host "    start               " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Inicia cluster após reboot do computador" -ForegroundColor $Colors.Muted
    Write-Host "    cleanup             " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Remove cluster, registry e recursos" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    Write-Host "  🔌 PORT-FORWARD:" -ForegroundColor $Colors.Info
    Write-Host "    port-forward [svc]  " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Inicia port-forwards (all/argocd/grafana)" -ForegroundColor $Colors.Muted
    Write-Host "    stop [svc]          " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Para port-forwards (all/argocd/grafana)" -ForegroundColor $Colors.Muted
    Write-Host "    list                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Lista port-forwards ativos" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    Write-Host "  🐳 DOCKER & NETWORK:" -ForegroundColor $Colors.Info
    Write-Host "    check               " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Verifica conectividade de rede do Docker" -ForegroundColor $Colors.Muted
    Write-Host "    headlamp            " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Inicia Headlamp UI (porta 4466)" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    Write-Host "  ℹ️  INFORMAÇÃO:" -ForegroundColor $Colors.Info
    Write-Host "    status              " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Mostra status completo do cluster" -ForegroundColor $Colors.Muted
    Write-Host "    help                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Mostra esta ajuda" -ForegroundColor $Colors.Muted
    Write-Host "    menu                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Abre menu interativo" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    Write-Host "📝 EXEMPLOS:" -ForegroundColor $Colors.Title
    Write-Host "  .\k3d-manager.ps1 create" -ForegroundColor $Colors.Muted
    Write-Host "  .\k3d-manager.ps1 start" -ForegroundColor $Colors.Muted
    Write-Host "  .\k3d-manager.ps1 port-forward all" -ForegroundColor $Colors.Muted
    Write-Host "  .\k3d-manager.ps1 port-forward argocd" -ForegroundColor $Colors.Muted
    Write-Host "  .\k3d-manager.ps1 stop argocd" -ForegroundColor $Colors.Muted
    Write-Host "  .\k3d-manager.ps1 status" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    Write-Host "🔗 ACESSO AOS SERVIÇOS:" -ForegroundColor $Colors.Title
    Write-Host "  ArgoCD:   http://localhost:8090  (admin / Argo@123)" -ForegroundColor $Colors.Info
    Write-Host "  Grafana:  http://localhost:3000  (rdpresser / rdpresser@123)" -ForegroundColor $Colors.Info
    Write-Host "  Headlamp: http://localhost:4466" -ForegroundColor $Colors.Info
    Write-Host ""
}

function Show-Status {
    Show-Header
    Write-Host "📊 STATUS DO CLUSTER K3D" -ForegroundColor $Colors.Title
    Write-Host ""
    
    # Docker
    Write-Host "🐳 Docker Desktop:" -ForegroundColor $Colors.Info
    try {
        docker version | Out-Null
        Write-Host "   ✅ Rodando" -ForegroundColor $Colors.Success
    } catch {
        Write-Host "   ❌ Não está rodando" -ForegroundColor $Colors.Error
        return
    }
    
    # Cluster k3d
    Write-Host "`n📦 Cluster K3D:" -ForegroundColor $Colors.Info
    $clusters = k3d cluster list 2>&1 | Out-String
    if ($clusters -match "dev") {
        Write-Host "   ✅ Cluster 'dev' encontrado" -ForegroundColor $Colors.Success
        
        # Containers
        $containers = docker ps --filter "name=k3d-dev" --format "{{.Names}}\t{{.Status}}"
        $running = ($containers | Measure-Object).Count
        Write-Host "   📦 Containers rodando: $running" -ForegroundColor $Colors.Info
    } else {
        Write-Host "   ❌ Cluster 'dev' não encontrado" -ForegroundColor $Colors.Error
        Write-Host "   💡 Execute: .\k3d-manager.ps1 create" -ForegroundColor $Colors.Warning
        return
    }
    
    # Kubectl
    Write-Host "`n⚙️  Kubernetes API:" -ForegroundColor $Colors.Info
    try {
        kubectl cluster-info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ API acessível" -ForegroundColor $Colors.Success
            
            # Nodes
            $nodes = kubectl get nodes --no-headers 2>$null
            if ($nodes) {
                $nodeCount = ($nodes | Measure-Object).Count
                Write-Host "   📍 Nodes prontos: $nodeCount" -ForegroundColor $Colors.Info
            }
        } else {
            Write-Host "   ⚠️  API não respondendo" -ForegroundColor $Colors.Warning
        }
    } catch {
        Write-Host "   ❌ Não foi possível conectar à API" -ForegroundColor $Colors.Error
    }
    
    # Port-forwards
    Write-Host "`n🔌 Port-Forwards:" -ForegroundColor $Colors.Info
    $kubectlProcs = Get-Process -Name kubectl -ErrorAction SilentlyContinue | Where-Object {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        $cmdLine -like "*port-forward*"
    }
    
    if ($kubectlProcs) {
        Write-Host "   ✅ Ativos: $($kubectlProcs.Count)" -ForegroundColor $Colors.Success
        Write-Host "   💡 Execute: .\k3d-manager.ps1 list" -ForegroundColor $Colors.Info
    } else {
        Write-Host "   ⚠️  Nenhum port-forward ativo" -ForegroundColor $Colors.Warning
        Write-Host "   💡 Execute: .\k3d-manager.ps1 port-forward all" -ForegroundColor $Colors.Info
    }
    
    Write-Host ""
}

function Show-Menu {
    while ($true) {
        Show-Header
        Write-Host "📋 MENU PRINCIPAL" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host "  [1] 🔧 Criar cluster do zero" -ForegroundColor $Colors.Info
        Write-Host "  [2] 🚀 Iniciar cluster (após reboot)" -ForegroundColor $Colors.Info
        Write-Host "  [3] 🔌 Port-forward (todos)" -ForegroundColor $Colors.Info
        Write-Host "  [4] 🔌 Port-forward (ArgoCD)" -ForegroundColor $Colors.Info
        Write-Host "  [5] 🔌 Port-forward (Grafana)" -ForegroundColor $Colors.Info
        Write-Host "  [6] 🛑 Parar port-forwards" -ForegroundColor $Colors.Info
        Write-Host "  [7] 📋 Listar port-forwards" -ForegroundColor $Colors.Info
        Write-Host "  [8] 🐳 Verificar Docker" -ForegroundColor $Colors.Info
        Write-Host "  [9] 📊 Status do cluster" -ForegroundColor $Colors.Info
        Write-Host " [10] 🎨 Iniciar Headlamp UI" -ForegroundColor $Colors.Info
        Write-Host " [11] 🗑️  Limpar tudo (cleanup)" -ForegroundColor $Colors.Info
        Write-Host "  [0] ❌ Sair" -ForegroundColor $Colors.Error
        Write-Host ""
        
        $choice = Read-Host "Escolha uma opção"
        
        switch ($choice) {
            "1" { Invoke-Command "create" }
            "2" { Invoke-Command "start" }
            "3" { Invoke-Command "port-forward" "all" }
            "4" { Invoke-Command "port-forward" "argocd" }
            "5" { Invoke-Command "port-forward" "grafana" }
            "6" { Invoke-Command "stop" "all" }
            "7" { Invoke-Command "list" }
            "8" { Invoke-Command "check" }
            "9" { Invoke-Command "status" }
            "10" { Invoke-Command "headlamp" }
            "11" { Invoke-Command "cleanup" }
            "0" { 
                Write-Host "`n👋 Até logo!" -ForegroundColor $Colors.Success
                exit 0 
            }
            default {
                Write-Host "`n❌ Opção inválida!" -ForegroundColor $Colors.Error
                Start-Sleep -Seconds 2
            }
        }
        
        Write-Host "`nPressione qualquer tecla para continuar..." -ForegroundColor $Colors.Muted
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Invoke-Command($cmd, $arg1 = "", $arg2 = "") {
    $scriptPath = $PSScriptRoot
    
    switch ($cmd.ToLower()) {
        "create" {
            Write-Host "`n🔧 Criando cluster do zero..." -ForegroundColor $Colors.Info
            & "$scriptPath\create-all-from-zero.ps1"
        }
        "start" {
            Write-Host "`n🚀 Iniciando cluster..." -ForegroundColor $Colors.Info
            & "$scriptPath\start-cluster.ps1"
        }
        "cleanup" {
            Write-Host "`n🗑️  Limpando recursos..." -ForegroundColor $Colors.Warning
            & "$scriptPath\cleanup-all.ps1"
        }
        "port-forward" {
            $svc = if ($arg1) { $arg1 } else { "all" }
            Write-Host "`n🔌 Iniciando port-forward ($svc)..." -ForegroundColor $Colors.Info
            & "$scriptPath\port-forward.ps1" $svc
        }
        { $_ -in "stop", "stop-port-forward" } {
            $svc = if ($arg1) { $arg1 } else { "all" }
            Write-Host "`n🛑 Parando port-forwards ($svc)..." -ForegroundColor $Colors.Info
            if ($arg1 -match '^\d+$') {
                & "$scriptPath\stop-port-forward.ps1" -Id $arg1
            } else {
                & "$scriptPath\stop-port-forward.ps1" $svc
            }
        }
        { $_ -in "list", "list-port-forward" } {
            Write-Host "`n📋 Listando port-forwards..." -ForegroundColor $Colors.Info
            & "$scriptPath\list-port-forward.ps1"
        }
        { $_ -in "check", "check-docker" } {
            Write-Host "`n🐳 Verificando Docker..." -ForegroundColor $Colors.Info
            & "$scriptPath\check-docker-network.ps1"
        }
        "headlamp" {
            Write-Host "`n🎨 Iniciando Headlamp..." -ForegroundColor $Colors.Info
            & "$scriptPath\start-headlamp-docker.ps1"
        }
        "status" {
            Show-Status
        }
        { $_ -in "help", "--help", "-h", "/?" } {
            Show-Help
        }
        "menu" {
            Show-Menu
        }
        default {
            Write-Host "`n❌ Comando desconhecido: $cmd" -ForegroundColor $Colors.Error
            Write-Host "Execute com --help para ver comandos disponíveis." -ForegroundColor $Colors.Muted
            exit 1
        }
    }
}

# Main execution
if (-not $Command) {
    # Sem parâmetros: abre menu interativo
    Show-Menu
} elseif ($Command -in @("help", "--help", "-h", "/?")) {
    Show-Help
} else {
    Invoke-Command $Command $Service $RemainingArgs
}
