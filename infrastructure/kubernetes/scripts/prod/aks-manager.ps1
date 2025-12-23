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
    ACRName       = "tccloudgamesdevcr8nacr"
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
    Write-Host "║          ☁️  AKS Cluster Manager v1.0                       ║" -ForegroundColor $Colors.Title
    Write-Host "║          Azure Kubernetes Service Manager                  ║" -ForegroundColor $Colors.Title
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
    Write-Host "    install-nginx       " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs NGINX Ingress Controller on AKS" -ForegroundColor $Colors.Muted
    Write-Host "    install-eso         " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs External Secrets Operator on AKS" -ForegroundColor $Colors.Muted
    Write-Host "    install-grafana     " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs Grafana Agent on AKS" -ForegroundColor $Colors.Muted
    Write-Host "    install-argocd      " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Installs ArgoCD on AKS cluster" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  🔐 SECRETS & CONFIGURATION:" -ForegroundColor $Colors.Info
    Write-Host "    setup-eso-wi        " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Configures ESO with Workload Identity (recommended)" -ForegroundColor $Colors.Muted
    # Removed legacy setup-eso (ClusterSecretStore). Use Workload Identity.
    Write-Host "    list-secrets        " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Lists secrets from Key Vault" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  🚀 DEPLOYMENT:" -ForegroundColor $Colors.Info
    Write-Host "    post-terraform-setup" -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Complete infrastructure setup after Terraform apply" -ForegroundColor $Colors.Muted
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
    Write-Host "  .\aks-manager.ps1 install-nginx" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-eso" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-grafana" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-argocd" -ForegroundColor $Colors.Muted
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
    function Get-InstallStatuses {
        # Start parallel jobs for faster info gathering
        $jobs = @()
        
        # Job 1: Check ArgoCD
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n argocd --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ argocd = [bool]$pods }
            } catch {
                return @{ argocd = $false }
            }
        }
        
        # Job 2: Check Grafana Agent
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n grafana-agent --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ grafana = [bool]$pods }
            } catch {
                return @{ grafana = $false }
            }
        }
        
        # Job 3: Check ESO
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n external-secrets --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ eso = [bool]$pods }
            } catch {
                return @{ eso = $false }
            }
        }
        
        # Job 4: Check NGINX
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n ingress-nginx --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ nginx = [bool]$pods }
            } catch {
                return @{ nginx = $false }
            }
        }
        
        # Job 5: Check ArgoCD PROD Application
        $jobs += Start-Job -ScriptBlock {
            try {
                $app = kubectl get application cloudgames-prod -n argocd --no-headers 2>$null
                return @{ apps = [bool]$app }
            } catch {
                return @{ apps = $false }
            }
        }
        
        # Job 6: Check ACR tags for all repos
        $jobs += Start-Job -ArgumentList $Config.ACRName -ScriptBlock {
            param($acrName)
            $acrTags = @{}
            $repos = @{
                user     = "users-api"
                games    = "games-api"
                payments = "payms-api"
            }
            foreach ($key in $repos.Keys) {
                try {
                    $tagsJson = az acr repository show-tags --name $acrName --repository $repos[$key] --orderby time_desc --top 1 --detail 2>$null | ConvertFrom-Json
                    if ($tagsJson) {
                        $item = $tagsJson | Select-Object -First 1
                        $acrTags[$key] = @{
                            tag = $item.name
                            lastUpdateTime = $item.lastUpdateTime
                        }
                    }
                } catch {}
            }
            return @{ acrTags = $acrTags }
        }
        
        # Job 7: Check NGINX LoadBalancer IP
        $jobs += Start-Job -ScriptBlock {
            try {
                $ip = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
                return @{ nginxIP = $ip }
            } catch {
                return @{ nginxIP = $null }
            }
        }
        
        # Animated spinner while waiting for jobs
        $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
        $frameIndex = 0
        Write-Host "`n🔎 Collecting cluster information " -NoNewline -ForegroundColor $Colors.Info
        
        while ($jobs | Where-Object { $_.State -eq 'Running' }) {
            Write-Host "`r🔎 Collecting cluster information $($frames[$frameIndex]) " -NoNewline -ForegroundColor $Colors.Info
            $frameIndex = ($frameIndex + 1) % $frames.Count
            Start-Sleep -Milliseconds 80
        }
        
        Write-Host "`r🔎 Collecting cluster information ✓  " -ForegroundColor $Colors.Success
        
        # Collect results
        $result = @{
            argocd  = $false
            grafana = $false
            eso     = $false
            nginx   = $false
            apps    = $false
            acrTags = @{}
            nginxIP = $null
        }
        
        foreach ($job in $jobs) {
            $jobResult = Receive-Job -Job $job -Wait -AutoRemoveJob
            if ($jobResult) {
                foreach ($key in $jobResult.Keys) {
                    $result[$key] = $jobResult[$key]
                }
            }
        }
        
        return $result
    }

    while ($true) {
        Show-Header
        
        # Parallel info collection with animated spinner
        $statuses = Get-InstallStatuses
        Write-Host "" # spacing

        Write-Host "📋 MAIN MENU (PRODUCTION)" -ForegroundColor $Colors.Title
        Write-Host ""

        $installed = { param($flag) if ($flag) { '(installed)' } else { '(not installed)' } }

        Write-Host "  [1] 🔌 Connect to AKS cluster" -ForegroundColor $Colors.Info
        Write-Host "  [2] 📊 Show cluster status" -ForegroundColor $Colors.Info
        Write-Host ""
        
        # ===== COMPONENT INSTALLATION =====
        Write-Host "  🔧 COMPONENT INSTALLATION:" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host ("  [3] 📦 Install NGINX Ingress {0}" -f (& $installed $statuses.nginx)) -ForegroundColor $(if ($statuses.nginx) { $Colors.Success } else { $Colors.Info })
        if ($statuses.nginxIP) {
            Write-Host ("       • LoadBalancer IP: {0}" -f $statuses.nginxIP) -ForegroundColor $Colors.Muted
        }
        Write-Host ("  [4] 🔐 Install External Secrets Operator {0}" -f (& $installed $statuses.eso)) -ForegroundColor $(if ($statuses.eso) { $Colors.Success } else { $Colors.Info })
        Write-Host ("  [5] 📊 Install Grafana Agent {0}" -f (& $installed $statuses.grafana)) -ForegroundColor $(if ($statuses.grafana) { $Colors.Success } else { $Colors.Info })
        Write-Host ""
        
        # ===== ARGOCD & DEPLOYMENT =====
        Write-Host "  📦 ARGOCD & DEPLOYMENT:" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host ("  [6] 📦 Install ArgoCD {0}" -f (& $installed $statuses.argocd)) -ForegroundColor $(if ($statuses.argocd) { $Colors.Success } else { $Colors.Info })
        Write-Host ("  [7] 🔗 Get ArgoCD URL & credentials") -ForegroundColor $Colors.Info
        Write-Host ""
        
        # ===== CONFIGURATION =====
        Write-Host "  ⚙️  CONFIGURATION:" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host "  [8] 🔐 Setup ESO with Workload Identity" -ForegroundColor $Colors.Info
        Write-Host ("  [9] 📋 Bootstrap ArgoCD PROD app {0}" -f (& $installed $statuses.apps)) -ForegroundColor $(if ($statuses.apps) { $Colors.Success } else { $Colors.Info })
        Write-Host ""
        
        # ===== BUILD & DEPLOY =====
        Write-Host "  🐳 BUILD & DEPLOY:" -ForegroundColor $Colors.Title
        Write-Host ""
        # ACR last builds per repo
        $acrUser    = $statuses.acrTags['user']
        $acrGames   = $statuses.acrTags['games']
        $acrPayments= $statuses.acrTags['payments']
        Write-Host " [10] 🐳 Build & Push images to ACR" -ForegroundColor $Colors.Info
        if ($acrUser -or $acrGames -or $acrPayments) {
            Write-Host ""
            if ($acrUser) {
                Write-Host ("       • users-api:   tag {0} at {1}" -f ($acrUser.tag), ($acrUser.lastUpdateTime)) -ForegroundColor $Colors.Muted
            }
            if ($acrGames) {
                Write-Host ("       • games-api:   tag {0} at {1}" -f ($acrGames.tag), ($acrGames.lastUpdateTime)) -ForegroundColor $Colors.Muted
            }
            if ($acrPayments) {
                Write-Host ("       • payms-api:   tag {0} at {1}" -f ($acrPayments.tag), ($acrPayments.lastUpdateTime)) -ForegroundColor $Colors.Muted
            }
        }
        Write-Host ""
        
        # ===== UTILITIES =====
        Write-Host "  🔧 UTILITIES:" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host " [11] 📝 View logs" -ForegroundColor $Colors.Info
        Write-Host " [12] 🔧 Post-Terraform Complete Setup" -ForegroundColor $Colors.Info
        Write-Host "       (All-in-one: connect, nginx, ESO, WI, grafana, deploy)" -ForegroundColor $Colors.Muted
        Write-Host ""
        
        # ===== EXIT =====
        Write-Host "  [0] ❌ Exit" -ForegroundColor $Colors.Error
        Write-Host ""

        $choice = Read-Host "Choose an option"

        switch ($choice) {
            "1" { Invoke-Command "connect" }
            "2" { Invoke-Command "status" }
            "3" { Invoke-Command "install-nginx" }
            "4" { Invoke-Command "install-eso" }
            "5" { Invoke-Command "install-grafana" }
            "6" { Invoke-Command "install-argocd" }
            "7" { Invoke-Command "get-argocd-url" }
            "8" { Invoke-Command "setup-eso-wi" }
            "9" { Invoke-Command "bootstrap" }
            "10" { 
                $api = Read-Host "API to build (all/user/games/payments) [all]"
                Invoke-Command "build-push" $api
            }
            "11" { 
                $comp = Read-Host "Component (argocd/grafana-agent/eso/nginx)"
                Invoke-Command "logs" $comp
            }
            "12" { Invoke-Command "post-terraform-setup" }
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
        "install-nginx" {
            Write-Host "`n📦 Installing NGINX Ingress..." -ForegroundColor $Colors.Info
            $forceResp = Read-Host "Force reinstall (uninstall first)? (y/N)"
            $useForce = $forceResp -eq "y" -or $forceResp -eq "Y"
            
            $installArgs = @{
                ResourceGroup = $Config.ResourceGroup
                ClusterName = $Config.ClusterName
            }
            if ($useForce) { $installArgs['Force'] = $true }
            
            & "$scriptPath\install-nginx-ingress.ps1" @installArgs
        }
        "install-eso" {
            Write-Host "`n📦 Installing External Secrets Operator..." -ForegroundColor $Colors.Info
            $forceResp = Read-Host "Force reinstall (uninstall first)? (y/N)"
            $useForce = $forceResp -eq "y" -or $forceResp -eq "Y"
            
            $installArgs = @{
                ResourceGroup = $Config.ResourceGroup
                ClusterName = $Config.ClusterName
            }
            if ($useForce) { $installArgs['Force'] = $true }
            
            & "$scriptPath\install-external-secrets.ps1" @installArgs
        }
        "install-grafana" {
            Write-Host "`n📦 Installing Grafana Agent..." -ForegroundColor $Colors.Info
            $forceResp = Read-Host "Force reinstall (uninstall first)? (y/N)"
            $useForce = $forceResp -eq "y" -or $forceResp -eq "Y"
            
            $installArgs = @{
                ResourceGroup = $Config.ResourceGroup
                ClusterName = $Config.ClusterName
            }
            if ($useForce) { $installArgs['Force'] = $true }
            
            & "$scriptPath\install-grafana-agent.ps1" @installArgs
        }
        # Removed legacy individual installers (Grafana Agent, ESO, NGINX).
        # Use "post-terraform-setup" to perform the complete setup.
        # Removed legacy ClusterSecretStore setup. Use setup-eso-wi.
        "setup-eso-wi" {
            Write-Host "`n🔐 Setting up ESO with Workload Identity..." -ForegroundColor $Colors.Info
            & "$scriptPath\setup-eso-workload-identity.ps1" -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName -KeyVaultName $Config.KeyVaultName
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
        "post-terraform-setup" {
            Write-Host "`n🔧 Post-Terraform Complete Infrastructure Setup" -ForegroundColor $Colors.Info
            Write-Host ""
            Write-Host "This will execute the complete setup after Terraform apply:" -ForegroundColor $Colors.Warning
            Write-Host "  1. Connect to AKS cluster" -ForegroundColor $Colors.Muted
            Write-Host "  2. Install NGINX Ingress Controller" -ForegroundColor $Colors.Muted
            Write-Host "  3. Get NGINX LoadBalancer IP" -ForegroundColor $Colors.Muted
            Write-Host "  4. Update Terraform variables with NGINX IP" -ForegroundColor $Colors.Muted
            Write-Host "  5. Re-run Terraform to update APIM backends" -ForegroundColor $Colors.Muted
            Write-Host "  6. Install External Secrets Operator" -ForegroundColor $Colors.Muted
            Write-Host "  7. Configure Workload Identity" -ForegroundColor $Colors.Muted
            Write-Host "  8. Install Grafana Agent (optional)" -ForegroundColor $Colors.Muted
            Write-Host "  9. Deploy applications via Kustomize" -ForegroundColor $Colors.Muted
            Write-Host ""
            $response = Read-Host "Continue with complete setup? (Y/n)"
            if ($response -eq "n" -or $response -eq "N") {
                Write-Host "❌ Setup cancelled" -ForegroundColor $Colors.Warning
                return
            }
            
            $env = if ($arg1) { $arg1 } else { "dev" }
            Write-Host ""
            Write-Host "  ℹ️  Force Reinstall Options:" -ForegroundColor $Colors.Info
            Write-Host "     [N] Upgrade in-place (no downtime, recommended)" -ForegroundColor $Colors.Success
            Write-Host "     [Y] Uninstall + Reinstall (complete cleanup, may cause downtime)" -ForegroundColor $Colors.Warning
            Write-Host ""
            $forceResp = Read-Host "Force reinstall of components (NGINX/ESO/Grafana)? (y/N)"
            $useForce = $forceResp -eq "y" -or $forceResp -eq "Y"
            
            Write-Host ""
            Write-Host "  ℹ️  Deploy via Kustomize (Step 9):"-ForegroundColor $Colors.Info
            Write-Host "     If using ArgoCD/GitOps, you should skip manual deploy" -ForegroundColor $Colors.Muted
            $skipDeployResp = Read-Host "Skip Kustomize deploy? (Y/n)"
            $skipDeploy = $skipDeployResp -ne "n" -and $skipDeployResp -ne "N"
            
            $setupScript = Join-Path $scriptPath "setup-complete-infrastructure.ps1"
            
            if (Test-Path $setupScript) {
                $scriptArgs = @{
                    ResourceGroup = $Config.ResourceGroup
                    ClusterName = $Config.ClusterName
                    KeyVaultName = $Config.KeyVaultName
                    Environment = $env
                }
                if ($useForce) { $scriptArgs['Force'] = $true }
                if ($skipDeploy) { $scriptArgs['SkipDeploy'] = $true }
                
                & $setupScript @scriptArgs
            }
            else {
                Write-Host "❌ Script not found: setup-complete-infrastructure.ps1" -ForegroundColor $Colors.Error
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
            Write-Host "`n🚀 Bootstrapping ArgoCD applications (PRODUCTION)..." -ForegroundColor $Colors.Info
            
            # Safety: Remove dev application if it exists (should not be in PROD)
            Write-Host "🧹 Checking for dev application..." -ForegroundColor $Colors.Warning
            $devApp = kubectl get application cloudgames-dev -n argocd --ignore-not-found 2>$null
            if ($devApp) {
                Write-Host "   ⚠️  Found cloudgames-dev - removing..." -ForegroundColor $Colors.Warning
                kubectl delete application cloudgames-dev -n argocd --wait=true 2>$null
                Write-Host "   ✅ Removed cloudgames-dev" -ForegroundColor $Colors.Success
            }
            else {
                Write-Host "   ✅ No dev application found" -ForegroundColor $Colors.Success
            }
            
            # Apply ArgoCD project first, then PRODUCTION manifest
            $manifestsPath = Join-Path (Split-Path (Split-Path $scriptPath -Parent) -Parent) "manifests"
            $projectManifest = "$manifestsPath\application-cloudgames-project-prod.yaml"
            $prodManifest = "$manifestsPath\application-cloudgames-prod.yaml"
            
            if (Test-Path $projectManifest) {
                Write-Host "`n🗂️  Ensuring ArgoCD project exists..." -ForegroundColor $Colors.Info
                Write-Host "   📄 application-cloudgames-project-prod.yaml" -ForegroundColor $Colors.Muted
                kubectl apply -f $projectManifest

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Applied application-cloudgames-project-prod.yaml" -ForegroundColor $Colors.Success
                }
                else {
                    Write-Host "   ❌ Failed to apply project manifest" -ForegroundColor $Colors.Error
                }
            }
            else {
                Write-Host "❌ Manifest not found: $projectManifest" -ForegroundColor $Colors.Error
            }
            
            if (Test-Path $prodManifest) {
                Write-Host "`n📦 Applying PRODUCTION manifest..." -ForegroundColor $Colors.Info
                Write-Host "   📄 application-cloudgames-prod.yaml" -ForegroundColor $Colors.Muted
                kubectl apply -f $prodManifest
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Applied application-cloudgames-prod.yaml" -ForegroundColor $Colors.Success
                    Write-Host "`n📊 Application Status:" -ForegroundColor $Colors.Info
                    kubectl get application cloudgames-prod -n argocd
                }
                else {
                    Write-Host "❌ Failed to apply manifest" -ForegroundColor $Colors.Error
                }
            }
            else {
                Write-Host "❌ Manifest not found: $prodManifest" -ForegroundColor $Colors.Error
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
