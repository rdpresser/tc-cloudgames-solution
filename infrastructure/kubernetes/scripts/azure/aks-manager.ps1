<#
.SYNOPSIS
  AKS Manager - Central orchestrator for Azure AKS cluster management.

.DESCRIPTION
  Main script that centralizes and facilitates access to all AKS cluster
  management scripts. Provides an interactive menu and command line support.

.PARAMETER Command
  Command to execute. Use --help to see the full list.

.PARAMETER Service
  Specific service name.

.EXAMPLE
  .\aks-manager.ps1
  # Opens interactive menu

.EXAMPLE
  .\aks-manager.ps1 --help
  # Shows all available commands

.EXAMPLE
  .\aks-manager.ps1 install-argocd
  # Installs ArgoCD on AKS

.EXAMPLE
  .\aks-manager.ps1 install-grafana-agent
  # Installs Grafana Agent on AKS
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

# =============================================================================
# Configuration
# =============================================================================
$script:Config = @{
    ResourceGroup = "tc-cloudgames-solution-dev-rg"
    ClusterName   = "tc-cloudgames-dev-cr8n-aks"
    KeyVaultName  = "tccloudgamesdevcr8nkv"
}

# Colors and formatting
$script:Colors = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "White"
    Muted   = "Gray"
}

function Show-Header {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Title
    Write-Host "║          ☁️  AKS Cluster Manager v1.0                      ║" -ForegroundColor $Colors.Title
    Write-Host "║          Azure Kubernetes Service Manager                 ║" -ForegroundColor $Colors.Title
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Title
    Write-Host ""
    Write-Host "  Resource Group: $($Config.ResourceGroup)" -ForegroundColor $Colors.Muted
    Write-Host "  Cluster Name:   $($Config.ClusterName)" -ForegroundColor $Colors.Muted
    Write-Host ""
}

function Show-Help {
    Show-Header

    Write-Host "📖 AVAILABLE COMMANDS:" -ForegroundColor $Colors.Title
    Write-Host ""

    Write-Host "  🔧 CLUSTER CONNECTION:" -ForegroundColor $Colors.Info
    Write-Host "    connect             " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Get AKS credentials and set kubectl context" -ForegroundColor $Colors.Muted
    Write-Host "    status              " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Shows complete cluster status" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  📦 COMPONENT INSTALLATION:" -ForegroundColor $Colors.Info
    Write-Host "    install-argocd      " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs ArgoCD on AKS cluster" -ForegroundColor $Colors.Muted
    Write-Host "    install-grafana-agent " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs Grafana Agent for observability" -ForegroundColor $Colors.Muted
    Write-Host "    install-eso         " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs External Secrets Operator" -ForegroundColor $Colors.Muted
    Write-Host "    install-nginx       " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs NGINX Ingress Controller" -ForegroundColor $Colors.Muted
    Write-Host "    install-all         " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs all components (ArgoCD, Grafana Agent, ESO, NGINX)" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  🔐 SECRETS & CONFIGURATION:" -ForegroundColor $Colors.Info
    Write-Host "    setup-eso           " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Configures ESO ClusterSecretStore for Key Vault" -ForegroundColor $Colors.Muted
    Write-Host "    list-secrets        " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Lists secrets from Key Vault" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  🚀 DEPLOYMENT:" -ForegroundColor $Colors.Info
    Write-Host "    bootstrap [env]     " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Bootstrap ArgoCD applications (dev/prod)" -ForegroundColor $Colors.Muted
    Write-Host "    build-push [api]    " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Build and push Docker images to ACR (all/user/games/payments)" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  🔧 MAINTENANCE:" -ForegroundColor $Colors.Info
    Write-Host "    get-argocd-url      " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Get ArgoCD LoadBalancer URL" -ForegroundColor $Colors.Muted
    Write-Host "    logs [component]    " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "View logs (argocd/grafana-agent/eso/nginx)" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  ℹ️  INFORMATION:" -ForegroundColor $Colors.Info
    Write-Host "    help                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Shows this help" -ForegroundColor $Colors.Muted
    Write-Host "    menu                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Opens interactive menu" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "📝 EXAMPLES:" -ForegroundColor $Colors.Title
    Write-Host "  .\aks-manager.ps1 connect" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-argocd" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-grafana-agent" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-all" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 get-argocd-url" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 bootstrap prod" -ForegroundColor $Colors.Muted
    Write-Host ""
}

function Show-Status {
    Show-Header
    Write-Host "📊 AKS CLUSTER STATUS" -ForegroundColor $Colors.Title
    Write-Host ""

    # Azure CLI
    Write-Host "☁️  Azure CLI:" -ForegroundColor $Colors.Info
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Host "   ✅ Logged in as: $($account.user.name)" -ForegroundColor $Colors.Success
            Write-Host "   📁 Subscription: $($account.name)" -ForegroundColor $Colors.Muted
        } else {
            Write-Host "   ❌ Not logged in" -ForegroundColor $Colors.Error
            Write-Host "   💡 Run: az login" -ForegroundColor $Colors.Warning
            return
        }
    }
    catch {
        Write-Host "   ❌ Azure CLI not installed or not logged in" -ForegroundColor $Colors.Error
        return
    }

    # AKS Cluster
    Write-Host "`n📦 AKS Cluster:" -ForegroundColor $Colors.Info
    try {
        $aks = az aks show --resource-group $Config.ResourceGroup --name $Config.ClusterName 2>$null | ConvertFrom-Json
        if ($aks) {
            Write-Host "   ✅ Cluster found: $($aks.name)" -ForegroundColor $Colors.Success
            Write-Host "   📍 Location: $($aks.location)" -ForegroundColor $Colors.Muted
            Write-Host "   🔄 State: $($aks.powerState.code)" -ForegroundColor $(if ($aks.powerState.code -eq "Running") { $Colors.Success } else { $Colors.Warning })
            Write-Host "   🏷️  Version: $($aks.kubernetesVersion)" -ForegroundColor $Colors.Muted
        }
        else {
            Write-Host "   ❌ Cluster not found" -ForegroundColor $Colors.Error
            return
        }
    }
    catch {
        Write-Host "   ❌ Could not get cluster info" -ForegroundColor $Colors.Error
        return
    }

    # Kubectl context
    Write-Host "`n⚙️  Kubectl Context:" -ForegroundColor $Colors.Info
    $context = kubectl config current-context 2>$null
    if ($context -eq $Config.ClusterName) {
        Write-Host "   ✅ Context set to: $context" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "   ⚠️  Current context: $context" -ForegroundColor $Colors.Warning
        Write-Host "   💡 Run: .\aks-manager.ps1 connect" -ForegroundColor $Colors.Info
    }

    # Kubernetes API
    Write-Host "`n🔌 Kubernetes API:" -ForegroundColor $Colors.Info
    try {
        kubectl cluster-info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ API accessible" -ForegroundColor $Colors.Success

            $nodes = kubectl get nodes --no-headers 2>$null
            if ($nodes) {
                $nodeCount = ($nodes | Measure-Object).Count
                Write-Host "   📍 Nodes: $nodeCount" -ForegroundColor $Colors.Muted
            }
        }
        else {
            Write-Host "   ❌ API not accessible" -ForegroundColor $Colors.Error
        }
    }
    catch {
        Write-Host "   ❌ Could not connect to API" -ForegroundColor $Colors.Error
    }

    # Installed Components
    Write-Host "`n📦 Installed Components:" -ForegroundColor $Colors.Info

    # ArgoCD
    $argocdPods = kubectl get pods -n argocd --no-headers 2>$null | Where-Object { $_ -match "Running" }
    if ($argocdPods) {
        $argocdIP = kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        Write-Host "   ✅ ArgoCD: Running (http://$argocdIP)" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "   ⚪ ArgoCD: Not installed" -ForegroundColor $Colors.Muted
    }

    # Grafana Agent
    $grafanaPods = kubectl get pods -n grafana-agent --no-headers 2>$null | Where-Object { $_ -match "Running" }
    if ($grafanaPods) {
        Write-Host "   ✅ Grafana Agent: Running" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "   ⚪ Grafana Agent: Not installed" -ForegroundColor $Colors.Muted
    }

    # External Secrets
    $esoPods = kubectl get pods -n external-secrets --no-headers 2>$null | Where-Object { $_ -match "Running" }
    if ($esoPods) {
        Write-Host "   ✅ External Secrets: Running" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "   ⚪ External Secrets: Not installed" -ForegroundColor $Colors.Muted
    }

    # NGINX Ingress
    $nginxPods = kubectl get pods -n ingress-nginx --no-headers 2>$null | Where-Object { $_ -match "Running" }
    if ($nginxPods) {
        $nginxIP = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        Write-Host "   ✅ NGINX Ingress: Running (IP: $nginxIP)" -ForegroundColor $Colors.Success
    }
    else {
        Write-Host "   ⚪ NGINX Ingress: Not installed" -ForegroundColor $Colors.Muted
    }

    Write-Host ""
}

function Show-Menu {
    while ($true) {
        Show-Header
        Write-Host "📋 MAIN MENU" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host "  [1] 🔌 Connect to AKS cluster" -ForegroundColor $Colors.Info
        Write-Host "  [2] 📊 Show cluster status" -ForegroundColor $Colors.Info
        Write-Host "  [3] 📦 Install ArgoCD" -ForegroundColor $Colors.Info
        Write-Host "  [4] 📈 Install Grafana Agent" -ForegroundColor $Colors.Info
        Write-Host "  [5] 🔐 Install External Secrets Operator" -ForegroundColor $Colors.Info
        Write-Host "  [6] 🌐 Install NGINX Ingress" -ForegroundColor $Colors.Info
        Write-Host "  [7] 🚀 Install ALL components" -ForegroundColor $Colors.Info
        Write-Host "  [8] 🔗 Get ArgoCD URL & credentials" -ForegroundColor $Colors.Info
        Write-Host "  [9] 📋 Bootstrap ArgoCD apps" -ForegroundColor $Colors.Info
        Write-Host " [10] 🐳 Build & Push images to ACR" -ForegroundColor $Colors.Info
        Write-Host " [11] 📋 View logs" -ForegroundColor $Colors.Info
        Write-Host "  [0] ❌ Exit" -ForegroundColor $Colors.Error
        Write-Host ""

        $choice = Read-Host "Choose an option"

        switch ($choice) {
            "1" { Invoke-Command "connect" }
            "2" { Invoke-Command "status" }
            "3" { Invoke-Command "install-argocd" }
            "4" { Invoke-Command "install-grafana-agent" }
            "5" { Invoke-Command "install-eso" }
            "6" { Invoke-Command "install-nginx" }
            "7" { Invoke-Command "install-all" }
            "8" { Invoke-Command "get-argocd-url" }
            "9" { Invoke-Command "bootstrap" }
            "10" { 
                $api = Read-Host "API to build (all/user/games/payments) [all]"
                if ([string]::IsNullOrWhiteSpace($api)) { $api = "all" }
                Invoke-Command "build-push" $api
            }
            "11" { 
                $comp = Read-Host "Component (argocd/grafana-agent/eso/nginx)"
                Invoke-Command "logs" $comp
            }
            "0" {
                Write-Host "`n👋 Goodbye!" -ForegroundColor $Colors.Success
                exit 0
            }
            default {
                Write-Host "`n❌ Invalid option!" -ForegroundColor $Colors.Error
                Start-Sleep -Seconds 2
            }
        }

        Write-Host "`nPress any key to continue..." -ForegroundColor $Colors.Muted
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Invoke-Command($cmd, $arg1 = "") {
    $scriptPath = $PSScriptRoot

    switch ($cmd.ToLower()) {
        "connect" {
            Write-Host "`n🔌 Connecting to AKS cluster..." -ForegroundColor $Colors.Info
            az aks get-credentials --resource-group $Config.ResourceGroup --name $Config.ClusterName --overwrite-existing
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Connected to $($Config.ClusterName)" -ForegroundColor $Colors.Success
                kubectl cluster-info
            }
        }
        "status" {
            Show-Status
        }
        "install-argocd" {
            Write-Host "`n📦 Installing ArgoCD..." -ForegroundColor $Colors.Info
            & "$scriptPath\install-argocd-aks.ps1" -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName
        }
        "install-grafana-agent" {
            Write-Host "`n📈 Installing Grafana Agent..." -ForegroundColor $Colors.Info
            & "$scriptPath\install-grafana-agent-aks.ps1" -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName
        }
        "install-eso" {
            Write-Host "`n🔐 Installing External Secrets Operator..." -ForegroundColor $Colors.Info
            & "$scriptPath\install-external-secrets-aks.ps1" -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName
        }
        "install-nginx" {
            Write-Host "`n🌐 Installing NGINX Ingress Controller..." -ForegroundColor $Colors.Info
            & "$scriptPath\install-nginx-ingress-aks.ps1" -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName
        }
        "install-all" {
            Write-Host "`n🚀 Installing ALL components..." -ForegroundColor $Colors.Info
            Invoke-Command "install-argocd"
            Invoke-Command "install-grafana-agent"
            Invoke-Command "install-eso"
            Invoke-Command "install-nginx"
            Write-Host "`n✅ All components installed!" -ForegroundColor $Colors.Success
        }
        "get-argocd-url" {
            Write-Host "`n🔗 ArgoCD Access Information:" -ForegroundColor $Colors.Info
            $ip = kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
            if ($ip) {
                Write-Host ""
                Write-Host "  URL:      http://$ip" -ForegroundColor $Colors.Success
                Write-Host "  Username: admin" -ForegroundColor $Colors.Info
                Write-Host "  Password: Argo@AKS123! (or your custom password)" -ForegroundColor $Colors.Info
                Write-Host ""
            }
            else {
                Write-Host "  ❌ ArgoCD LoadBalancer IP not found" -ForegroundColor $Colors.Error
                Write-Host "  💡 Run: .\aks-manager.ps1 install-argocd" -ForegroundColor $Colors.Warning
            }
        }
        { $_ -in "build-push", "build-push-acr" } {
            $api = if ($arg1) { $arg1 } else { "all" }
            Write-Host "`n🐳 Building and pushing Docker images to ACR ($api)..." -ForegroundColor $Colors.Info
            $buildScript = Join-Path $scriptPath "build-push-acr.ps1"
            if (Test-Path $buildScript) {
                & $buildScript -Api $api
            }
            else {
                Write-Host "❌ Script not found: build-push-acr.ps1" -ForegroundColor $Colors.Error
            }
        }
        { $_ -in "bootstrap", "bootstrap-argocd" } {
            $env = if ($arg1) { $arg1 } else { "dev" }
            Write-Host "`n🚀 Bootstrapping ArgoCD applications ($env)..." -ForegroundColor $Colors.Info
            # Apply ArgoCD Application manifests
            $manifestsPath = Join-Path (Split-Path (Split-Path $scriptPath -Parent) -Parent) "manifests"
            if (Test-Path "$manifestsPath\application-cloudgames-$env.yaml") {
                kubectl apply -f "$manifestsPath\application-cloudgames-$env.yaml"
                Write-Host "✅ Applied application-cloudgames-$env.yaml" -ForegroundColor $Colors.Success
            }
            else {
                Write-Host "❌ Manifest not found: application-cloudgames-$env.yaml" -ForegroundColor $Colors.Error
            }
        }
        "logs" {
            $component = if ($arg1) { $arg1 } else { "argocd" }
            Write-Host "`n📋 Logs for $component..." -ForegroundColor $Colors.Info
            switch ($component) {
                "argocd" { kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50 }
                "grafana-agent" { kubectl logs -n grafana-agent -l app.kubernetes.io/name=grafana-agent --tail=50 }
                "eso" { kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50 }
                "nginx" { kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 }
                default { Write-Host "Unknown component: $component" -ForegroundColor $Colors.Error }
            }
        }
        { $_ -in "help", "--help", "-h", "/?" } {
            Show-Help
        }
        "menu" {
            Show-Menu
        }
        default {
            Write-Host "`n❌ Unknown command: $cmd" -ForegroundColor $Colors.Error
            Write-Host "Run with --help to see available commands." -ForegroundColor $Colors.Muted
            exit 1
        }
    }
}

# =============================================================================
# Main execution
# =============================================================================
if (-not $Command) {
    Show-Menu
}
elseif ($Command -in @("help", "--help", "-h", "/?")) {
    Show-Help
}
else {
    Invoke-Command $Command $Service
}
