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
    .\aks-manager.ps1 configure-image-updater
    # Configures ArgoCD Image Updater
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

    Write-Host "  📦 COMPONENT INSTALLATION (ArgoCD-managed):" -ForegroundColor $Colors.Info
    Write-Host "    install-nginx       " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Validate NGINX Ingress (installed via ArgoCD/Helm)" -ForegroundColor $Colors.Muted
    Write-Host "    install-eso         " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Validate ESO (installed via ArgoCD/Helm)" -ForegroundColor $Colors.Muted
    Write-Host "    install-argocd      " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Install Argo CD via YAML (kubectl). Usage: install-argocd [namespace]" -ForegroundColor $Colors.Muted
    Write-Host "    configure-image-updater" -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Configures ArgoCD Image Updater (secret or Workload Identity)" -ForegroundColor $Colors.Muted
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
    Write-Host "View logs (argocd/eso/nginx)" -ForegroundColor $Colors.Muted
    Write-Host "    check-versions      " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Check Helm chart versions for updates" -ForegroundColor $Colors.Muted
    Write-Host "    update-chart        " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Update Helm chart version in manifest" -ForegroundColor $Colors.Muted
    Write-Host "    fix-argocd-sync     " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Recover ArgoCD sync issues (manual webhook fix)" -ForegroundColor $Colors.Muted
    Write-Host "    cleanup-audit       " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Analyze what can be safely deleted from cluster" -ForegroundColor $Colors.Muted
    Write-Host "    reset-cluster       " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "⚠️  DANGEROUS: Clean AKS cluster (keep only system namespaces)" -ForegroundColor $Colors.Muted
    Write-Host "    force-delete-ns [name]" -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Force delete namespace stuck in Terminating" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "  ℹ️  INFORMATION:" -ForegroundColor $Colors.Info
    Write-Host "    help                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Shows this help" -ForegroundColor $Colors.Muted
    Write-Host "    menu                " -NoNewline -ForegroundColor $Colors.Success
    Write-Host "Opens interactive menu" -ForegroundColor $Colors.Muted
    Write-Host ""

    Write-Host "📝 EXAMPLES:" -ForegroundColor $Colors.Title
    Write-Host "  .\aks-manager.ps1 connect" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-nginx  # validate (ArgoCD-managed)" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-eso    # validate (ArgoCD-managed)" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 install-argocd" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 get-argocd-url" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 bootstrap prod" -ForegroundColor $Colors.Muted
    Write-Host "  .\aks-manager.ps1 check-versions # Check Helm chart updates" -ForegroundColor $Colors.Muted
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
        
        # Job 2: Check ESO
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n external-secrets --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ eso = [bool]$pods }
            } catch {
                return @{ eso = $false }
            }
        }
        
        # Job 3: Check NGINX
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n ingress-nginx --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ nginx = [bool]$pods }
            } catch {
                return @{ nginx = $false }
            }
        }
        
        # Job 4: Check ArgoCD PROD Application
        $jobs += Start-Job -ScriptBlock {
            try {
                $app = kubectl get application cloudgames-prod -n argocd --no-headers 2>$null
                return @{ apps = [bool]$app }
            } catch {
                return @{ apps = $false }
            }
        }
        
        # Job 5: Check ACR tags for all repos
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
        
        # Job 6: Check NGINX LoadBalancer IP
        $jobs += Start-Job -ScriptBlock {
            try {
                $ip = kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
                return @{ nginxIP = $ip }
            } catch {
                return @{ nginxIP = $null }
            }
        }
        
        # Job 7: Check ArgoCD Image Updater
        $jobs += Start-Job -ScriptBlock {
            try {
                $pods = kubectl get pods -n argocd-image-updater --no-headers 2>$null | Where-Object { $_ -match "Running" }
                return @{ imageUpdater = [bool]$pods }
            } catch {
                return @{ imageUpdater = $false }
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
            argocd       = $false
            eso          = $false
            nginx        = $false
            apps         = $false
            imageUpdater = $false
            acrTags      = @{}
            nginxIP      = $null
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
        Write-Host "  🔧 COMPONENT INSTALLATION (ArgoCD-managed):" -ForegroundColor $Colors.Title
        Write-Host ""
        Write-Host ("  [3] 📦 Validate NGINX Ingress {0}" -f (& $installed $statuses.nginx)) -ForegroundColor $(if ($statuses.nginx) { $Colors.Success } else { $Colors.Info })
        if ($statuses.nginxIP) {
            Write-Host ("       • LoadBalancer IP: {0}" -f $statuses.nginxIP) -ForegroundColor $Colors.Muted
        }
        Write-Host ("  [4] 🔐 Validate External Secrets Operator {0}" -f (& $installed $statuses.eso)) -ForegroundColor $(if ($statuses.eso) { $Colors.Success } else { $Colors.Info })
        Write-Host "       • Installed via ArgoCD (application-external-secrets.yaml)" -ForegroundColor $Colors.Muted
        Write-Host ("  [5] 📦 Install ArgoCD {0}" -f (& $installed $statuses.argocd)) -ForegroundColor $(if ($statuses.argocd) { $Colors.Success } else { $Colors.Info })
        Write-Host ("  [6] 🔄 Configure Image Updater (Workload Identity) {0}" -f (& $installed $statuses.imageUpdater)) -ForegroundColor $(if ($statuses.imageUpdater) { $Colors.Success } else { $Colors.Info })
        Write-Host "       • Uses Managed Identity (no secrets required)" -ForegroundColor $Colors.Muted
        Write-Host ""
        
        # ===== ARGOCD & DEPLOYMENT =====
        Write-Host "  📦 ARGOCD & DEPLOYMENT:" -ForegroundColor $Colors.Title
        Write-Host ""
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
        Write-Host "       (All-in-one: connect → ArgoCD → bootstrap → ESO → Image Updater)" -ForegroundColor $Colors.Muted
        Write-Host " [13] 📊 Check Helm chart versions" -ForegroundColor $Colors.Info
        Write-Host "       (Check for updates to ingress-nginx, ESO, workload-identity)" -ForegroundColor $Colors.Muted
        Write-Host " [14] 🔄 Check ArgoCD Updates" -ForegroundColor $Colors.Info
        Write-Host "       (View available ArgoCD versions from GitHub)" -ForegroundColor $Colors.Muted
        Write-Host " [15] � Cleanup Audit" -ForegroundColor $Colors.Info
        Write-Host "       (Analyze what can be safely deleted)" -ForegroundColor $Colors.Muted
        Write-Host " [16] 🗑️  Reset Cluster (DANGEROUS)" -ForegroundColor $Colors.Error
        Write-Host "       (Delete all workloads, keep only system namespaces)" -ForegroundColor $Colors.Muted
        Write-Host " [17] 💥 Force Delete Namespace" -ForegroundColor $Colors.Error
        Write-Host "       (Force delete stuck Terminating namespace)" -ForegroundColor $Colors.Muted
        Write-Host " [18] 🔄 Recover ArgoCD Sync" -ForegroundColor $Colors.Info
        Write-Host "       (Manually fix webhook sync issues if needed)" -ForegroundColor $Colors.Muted
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
            "5" { Invoke-Command "install-argocd" }
            "6" { Invoke-Command "configure-image-updater" }
            "7" { Invoke-Command "get-argocd-url" }
            "8" { Invoke-Command "setup-eso-wi" }
            "9" { Invoke-Command "bootstrap" }
            "10" { 
                $api = Read-Host "API to build (all/user/games/payments) [all]"
                Invoke-Command "build-push" $api
            }
            "11" { 
                $comp = Read-Host "Component (argocd/eso/nginx)"
                Invoke-Command "logs" $comp
            }
            "12" { Invoke-Command "post-terraform-setup" }
            "13" { Invoke-Command "check-versions" }
            "14" { Invoke-Command "check-argocd-updates" }
            "15" { Invoke-Command "cleanup-audit" }
            "16" { Invoke-Command "reset-cluster" }
            "17" { 
                $ns = Read-Host "Namespace name"
                Invoke-Command "force-delete-ns" $ns
            }
            "17" {
                Invoke-Command "force-delete-ns"
            }
            "18" {
                & "$PSScriptRoot\fix-argocd-sync.ps1"
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
            Write-Host "`n📦 Installing Argo CD via YAML into namespace 'argocd'..." -ForegroundColor $Colors.Info
            $script = Join-Path $scriptPath "install-argocd-aks.ps1"
            if (Test-Path $script) {
                & $script -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName -Namespace "argocd"
            } else {
                Write-Host "❌ Script not found: install-argocd-aks.ps1" -ForegroundColor $Colors.Error
            }
        }
        "install-nginx" {
            Write-Host "`n📦 Validating NGINX Ingress (ArgoCD-managed)..." -ForegroundColor $Colors.Info
            $installArgs = @{
                ResourceGroup = $Config.ResourceGroup
                ClusterName   = $Config.ClusterName
            }
            & "$scriptPath\install-nginx-ingress.ps1" @installArgs
        }
        "install-eso" {
            Write-Host "`n� Validating External Secrets Operator..." -ForegroundColor $Colors.Info
            Write-Host "   (ESO is now installed via ArgoCD Application)" -ForegroundColor $Colors.Muted
            Write-Host ""
            
            $installArgs = @{
                ResourceGroup = $Config.ResourceGroup
                ClusterName = $Config.ClusterName
            }
            
            & "$scriptPath\install-external-secrets.ps1" @installArgs
        }
        "install-argocd-image-updater" {
            Write-Host "`n📦 Installing ArgoCD Image Updater..." -ForegroundColor $Colors.Info
            & "$scriptPath\install-argocd-image-updater.ps1" `
                -ResourceGroup $Config.ResourceGroup `
                -ClusterName $Config.ClusterName `
                -KeyVaultName $Config.KeyVaultName `
                -ACRLoginServer "$($Config.ACRName).azurecr.io"
        }
        # Removed legacy individual installers (ESO, NGINX).
        # Use "post-terraform-setup" to perform the complete setup.
        # Removed legacy ClusterSecretStore setup. Use setup-eso-wi.
        "setup-eso-wi" {
            Write-Host "`n🔐 Setting up ESO with Workload Identity..." -ForegroundColor $Colors.Info
            & "$scriptPath\setup-eso-workload-identity.ps1" -ResourceGroup $Config.ResourceGroup -ClusterName $Config.ClusterName -KeyVaultName $Config.KeyVaultName
        }
        { $_ -in "configure-image-updater", "setup-image-updater" } {
            Write-Host "`n🔄 Configuring ArgoCD Image Updater..." -ForegroundColor $Colors.Info
            Write-Host ""
            Write-Host "Choose authentication method:" -ForegroundColor $Colors.Warning
            Write-Host "  [1] Secret-based (simpler, dev/staging)" -ForegroundColor $Colors.Info
            Write-Host "  [2] Workload Identity (more secure, production)" -ForegroundColor $Colors.Info
            Write-Host ""
            $authChoice = Read-Host "Authentication method (1/2) [2]"

            $useWI = $authChoice -eq "2"

            $scriptArgs = @{
                ResourceGroup = $Config.ResourceGroup
                ClusterName = $Config.ClusterName
                AcrName = $Config.ACRName
            }

            if ($useWI) {
                $scriptArgs['UseWorkloadIdentity'] = $true
                Write-Host "✅ Using Workload Identity" -ForegroundColor $Colors.Success
            }
            else {
                $scriptArgs['UseWorkloadIdentity'] = $false
                Write-Host "✅ Using Secret-based authentication" -ForegroundColor $Colors.Success
            }

            $imageUpdaterScript = Join-Path $scriptPath "configure-image-updater.ps1"
            if (Test-Path $imageUpdaterScript) {
                & $imageUpdaterScript @scriptArgs
            }
            else {
                Write-Host "❌ Script not found: configure-image-updater.ps1" -ForegroundColor $Colors.Error
            }
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
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host "Pre-Flight Status Check (IDEMPOTENT SETUP)" -ForegroundColor $Colors.Title
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host ""
            
            # Pre-flight checks
            Write-Host "Checking current installation status..." -ForegroundColor $Colors.Info
            Write-Host ""
            
            $statusArgoCD = $(kubectl get pods -n argocd --selector=app.kubernetes.io/name=argocd-server --no-headers 2>$null | wc -l) -gt 0
            $statusESO = $(kubectl get pods -n external-secrets --selector=app.kubernetes.io/name=external-secrets --no-headers 2>$null | wc -l) -gt 0
            $statusImageUpdater = $(kubectl get pods -n argocd-image-updater --no-headers 2>$null | wc -l) -gt 0
            $statusNGINX = $(kubectl get pods -n ingress-nginx --selector=app.kubernetes.io/name=ingress-nginx --no-headers 2>$null | wc -l) -gt 0
            
            Write-Host "Installation Status:" -ForegroundColor $Colors.Info
            Write-Host "  $(if ($statusArgoCD) { '✅' } else { '⭕' }) ArgoCD" -ForegroundColor $(if ($statusArgoCD) { 'Green' } else { 'Yellow' })
            Write-Host "  $(if ($statusNGINX) { '✅' } else { '⭕' }) NGINX Ingress" -ForegroundColor $(if ($statusNGINX) { 'Green' } else { 'Yellow' })
            Write-Host "  $(if ($statusESO) { '✅' } else { '⭕' }) External Secrets Operator" -ForegroundColor $(if ($statusESO) { 'Green' } else { 'Yellow' })
            Write-Host "  $(if ($statusImageUpdater) { '✅' } else { '⭕' }) Image Updater" -ForegroundColor $(if ($statusImageUpdater) { 'Green' } else { 'Yellow' })
            Write-Host ""
            
            Write-Host "Setup Philosophy:" -ForegroundColor $Colors.Info
            Write-Host "  • IDEMPOTENT: Safe to run multiple times" -ForegroundColor $Colors.Muted
            Write-Host "  • SKIP existing: Won't reinstall components" -ForegroundColor $Colors.Muted
            Write-Host "  • PRESERVE configs: Never breaks existing setup" -ForegroundColor $Colors.Muted
            Write-Host "  • ADD missing: Installs only needed components" -ForegroundColor $Colors.Muted
            Write-Host ""
            
            Write-Host "Execution Plan:" -ForegroundColor $Colors.Warning
            Write-Host "  1. Connect to AKS cluster (always safe)" -ForegroundColor $Colors.Muted
            Write-Host "  2. Install ArgoCD (skips if exists)" -ForegroundColor $Colors.Muted
            Write-Host "  3. Bootstrap applications (idempotent apply)" -ForegroundColor $Colors.Muted
            Write-Host "  4. Setup ESO Workload Identity (verifies each step)" -ForegroundColor $Colors.Muted
            Write-Host "  5. Configure Image Updater (idempotent Helm)" -ForegroundColor $Colors.Muted
            Write-Host ""
            
            $response = Read-Host "Continue with idempotent setup? (Y/n)"
            if ($response -eq "n" -or $response -eq "N") {
                Write-Host "❌ Setup cancelled" -ForegroundColor $Colors.Warning
                return
            }
            
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host "Executing Complete Infrastructure Setup..." -ForegroundColor $Colors.Title
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host ""
            
            # Step 1: Connect to AKS
            Write-Host "Step 1/5: Connecting to AKS cluster..." -ForegroundColor $Colors.Info
            Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
            Invoke-Command "connect"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "`n❌ Failed to connect to AKS cluster" -ForegroundColor $Colors.Error
                return
            }
            Write-Host "✅ Step 1 completed`n" -ForegroundColor $Colors.Success
            Start-Sleep -Seconds 2
            
            # Step 2: Install ArgoCD
            Write-Host "Step 2/5: Installing ArgoCD..." -ForegroundColor $Colors.Info
            Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
            Invoke-Command "install-argocd"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "`n❌ Failed to install ArgoCD" -ForegroundColor $Colors.Error
                return
            }
            Write-Host "✅ Step 2 completed`n" -ForegroundColor $Colors.Success
            Start-Sleep -Seconds 2
            
            # Step 3: Bootstrap ArgoCD applications
            Write-Host "Step 3/5: Bootstrapping ArgoCD applications (PROD)..." -ForegroundColor $Colors.Info
            Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
            Invoke-Command "bootstrap"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "`n❌ Failed to bootstrap applications" -ForegroundColor $Colors.Error
                return
            }
            Write-Host "✅ Step 3 completed`n" -ForegroundColor $Colors.Success
            
            # Wait for ArgoCD Applications to be ready before Workload Identity setup
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host "Waiting for Platform Components..." -ForegroundColor $Colors.Title
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            & "$scriptPath\wait-for-components.ps1" -TimeoutSeconds 300
            
            # Step 4: Setup ESO with Workload Identity
            Write-Host "Step 4/5: Configuring ESO with Workload Identity..." -ForegroundColor $Colors.Info
            Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
            Invoke-Command "setup-eso-wi"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "`n⚠️  Warning: ESO setup had issues (non-critical)" -ForegroundColor $Colors.Warning
            } else {
                Write-Host "✅ Step 4 completed`n" -ForegroundColor $Colors.Success
            }
            Start-Sleep -Seconds 2
            
            # Step 5: Configure Image Updater
            Write-Host "Step 5/5: Configuring ArgoCD Image Updater..." -ForegroundColor $Colors.Info
            Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor $Colors.Muted
            Write-Host "Using Workload Identity for ACR authentication..." -ForegroundColor $Colors.Muted
            Invoke-Command "configure-image-updater"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "`n⚠️  Warning: Image Updater setup had issues (non-critical)" -ForegroundColor $Colors.Warning
            } else {
                Write-Host "✅ Step 5 completed`n" -ForegroundColor $Colors.Success
            }
            
            Write-Host ""
            Write-Host "Ensuring all ArgoCD applications are synced before completion..." -ForegroundColor $Colors.Info
            & "$PSScriptRoot\fix-argocd-sync.ps1"
            
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host "✅ Complete Infrastructure Setup Finished!" -ForegroundColor $Colors.Success
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Title
            Write-Host ""
            Write-Host "� Idempotency Guarantee:" -ForegroundColor $Colors.Info
            Write-Host "   This setup is fully idempotent. You can:" -ForegroundColor $Colors.Muted
            Write-Host "   • Rerun this option [12] anytime without risk" -ForegroundColor $Colors.Muted
            Write-Host "   • It will skip installed components" -ForegroundColor $Colors.Muted
            Write-Host "   • It will only add missing pieces" -ForegroundColor $Colors.Muted
            Write-Host "   • It will never break existing configurations" -ForegroundColor $Colors.Muted
            Write-Host ""
            Write-Host "�📊 Next steps:" -ForegroundColor $Colors.Info
            Write-Host "  1. Get ArgoCD URL:  .\aks-manager.ps1 get-argocd-url" -ForegroundColor $Colors.Muted
            Write-Host "  2. Check status:     .\aks-manager.ps1 status" -ForegroundColor $Colors.Muted
            Write-Host "  3. Build images:     .\aks-manager.ps1 build-push all" -ForegroundColor $Colors.Muted
            Write-Host ""
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
            
            # Apply ArgoCD project first, then platform components, then PRODUCTION manifest
            $manifestsPath = Join-Path (Split-Path (Split-Path $scriptPath -Parent) -Parent) "manifests"
            $projectManifest = "$manifestsPath\application-cloudgames-project-prod.yaml"
            $azureWIManifest = "$manifestsPath\application-azure-workload-identity.yaml"
            $nginxManifest = "$manifestsPath\application-ingress-nginx.yaml"
            $esoManifest = "$manifestsPath\application-external-secrets.yaml"
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
            
            # Apply Azure Workload Identity Webhook (required for WI to work)
            if (Test-Path $azureWIManifest) {
                Write-Host "`n🔑 Installing Azure Workload Identity Webhook..." -ForegroundColor $Colors.Info
                Write-Host "   📄 application-azure-workload-identity.yaml" -ForegroundColor $Colors.Muted
                kubectl apply -f $azureWIManifest

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Applied application-azure-workload-identity.yaml" -ForegroundColor $Colors.Success
                }
                else {
                    Write-Host "   ❌ Failed to apply Azure WI manifest" -ForegroundColor $Colors.Error
                }
            }
            else {
                Write-Host "❌ Manifest not found: $azureWIManifest" -ForegroundColor $Colors.Error
            }
            
            # Apply NGINX Ingress Controller (LoadBalancer)
            if (Test-Path $nginxManifest) {
                Write-Host "`n🌐 Installing NGINX Ingress Controller..." -ForegroundColor $Colors.Info
                Write-Host "   📄 application-ingress-nginx.yaml" -ForegroundColor $Colors.Muted
                kubectl apply -f $nginxManifest

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Applied application-ingress-nginx.yaml" -ForegroundColor $Colors.Success
                }
                else {
                    Write-Host "   ❌ Failed to apply NGINX manifest" -ForegroundColor $Colors.Error
                }
            }
            else {
                Write-Host "❌ Manifest not found: $nginxManifest" -ForegroundColor $Colors.Error
            }
            
            # Apply External Secrets Operator (platform component)
            if (Test-Path $esoManifest) {
                Write-Host "`n🔐 Installing External Secrets Operator..." -ForegroundColor $Colors.Info
                Write-Host "   📄 application-external-secrets.yaml" -ForegroundColor $Colors.Muted
                kubectl apply -f $esoManifest

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Applied application-external-secrets.yaml" -ForegroundColor $Colors.Success
                }
                else {
                    Write-Host "   ❌ Failed to apply ESO manifest" -ForegroundColor $Colors.Error
                }
            }
            else {
                Write-Host "❌ Manifest not found: $esoManifest" -ForegroundColor $Colors.Error
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
        "reset-cluster" {
            Write-Host "`n⚠️  DANGEROUS OPERATION - CLUSTER RESET" -ForegroundColor $Colors.Error
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Error
            Write-Host ""
            Write-Host "This will DELETE all resources except:" -ForegroundColor $Colors.Warning
            Write-Host "  • System namespaces (kube-system, kube-public, kube-node-lease)" -ForegroundColor $Colors.Muted
            Write-Host "  • default namespace" -ForegroundColor $Colors.Muted
            Write-Host ""
            Write-Host "This will be DELETED:" -ForegroundColor $Colors.Error
            Write-Host "  ✗ All custom namespaces" -ForegroundColor $Colors.Muted
            Write-Host "  ✗ All ClusterRoles/ClusterRoleBindings (non-system)" -ForegroundColor $Colors.Muted
            Write-Host "  ✗ All ServiceAccounts (non-system)" -ForegroundColor $Colors.Muted
            Write-Host "  ✗ All CRDs and their instances" -ForegroundColor $Colors.Muted
            Write-Host "  ✗ All Webhooks (Validation, Mutation)" -ForegroundColor $Colors.Muted
            Write-Host "  ✗ All Helm releases" -ForegroundColor $Colors.Muted
            Write-Host ""
            Write-Host "This WILL NOT affect:" -ForegroundColor $Colors.Success
            Write-Host "  ✓ System namespaces and core components" -ForegroundColor $Colors.Muted
            Write-Host "  ✓ Azure infrastructure (AKS, ACR, Key Vault, etc)" -ForegroundColor $Colors.Muted
            Write-Host "  ✓ Terraform state" -ForegroundColor $Colors.Muted
            Write-Host "  ✓ Node pools and node data" -ForegroundColor $Colors.Muted
            Write-Host ""
            
            $confirm = Read-Host "Type 'yes I understand' to proceed with reset"
            if ($confirm -ne "yes I understand") {
                Write-Host "`n❌ Reset cancelled" -ForegroundColor $Colors.Success
                return
            }
            
            Write-Host "`n🔄 Starting cluster reset..." -ForegroundColor $Colors.Warning
            Write-Host ""
            
            # ⚠️ CRITICAL: Delete Webhooks FIRST (they block resource deletion!)
            Write-Host "⚠️  CRITICAL STEP - Deleting Webhooks FIRST..." -ForegroundColor $Colors.Error
            Write-Host "   (Webhooks prevent deletion of ExternalSecrets, ImageUpdaters, etc)" -ForegroundColor $Colors.Muted
            
            $webhooksToDelete = @(
                "externalsecret-validate",
                "secretstore-validate",
                "ingress-nginx-admission",
                "azure-wi-webhook-mutating-webhook-configuration",
                "eso-webhook"
            )
            
            foreach ($webhook in $webhooksToDelete) {
                try {
                    kubectl delete validatingwebhookconfiguration $webhook --ignore-not-found 2>$null
                    kubectl delete mutatingwebhookconfiguration $webhook --ignore-not-found 2>$null
                } catch {
                    # Continue
                }
            }
            Write-Host "   ✅ Webhooks deleted" -ForegroundColor $Colors.Success
            Write-Host ""
            
            # Helper function to delete with timeout
            function Delete-WithTimeout {
                param([string]$resource, [string]$name, [string]$namespace = $null, [int]$timeout = 10)
                
                try {
                    if ($namespace) {
                        timeout /t $timeout /nobreak > $null 2>&1 &
                        kubectl delete $resource $name -n $namespace --wait=false --ignore-not-found 2>$null
                    } else {
                        kubectl delete $resource $name --wait=false --ignore-not-found 2>$null
                    }
                    return $true
                } catch {
                    return $false
                }
            }
            
            # Step 1: Delete ArgoCD Applications FIRST (they can recreate resources)
            Write-Host "🗑️  Step 2/9: Deleting ArgoCD Applications..." -ForegroundColor $Colors.Info
            try {
                $argoApps = kubectl get applications -n argocd --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
                if ($argoApps) {
                    foreach ($app in $argoApps) {
                        Write-Host "   🗑️  Deleting: $app" -ForegroundColor $Colors.Warning
                        kubectl delete application $app -n argocd --wait=false 2>$null
                    }
                    Write-Host "   ✅ ArgoCD Applications deleted" -ForegroundColor $Colors.Success
                } else {
                    Write-Host "   ⭕ No ArgoCD Applications found" -ForegroundColor $Colors.Muted
                }
            } catch {
                Write-Host "   ⚠️  Error deleting applications (continuing)" -ForegroundColor $Colors.Warning
            }
            Write-Host ""
            
            # Step 2: Delete CRD instances BEFORE CRDs
            Write-Host "🗑️  Step 3/9: Deleting CRD instances..." -ForegroundColor $Colors.Info
            try {
                Write-Host "   🗑️  ExternalSecrets..." -ForegroundColor $Colors.Warning
                kubectl delete externalsecrets --all --all-namespaces --wait=false --ignore-not-found 2>$null
                
                Write-Host "   🗑️  ClusterSecretStores..." -ForegroundColor $Colors.Warning
                kubectl delete clustersecretstores --all --wait=false --ignore-not-found 2>$null
                
                Write-Host "   🗑️  SecretStores..." -ForegroundColor $Colors.Warning
                kubectl delete secretstores --all --all-namespaces --wait=false --ignore-not-found 2>$null
                
                Write-Host "   🗑️  ImageUpdaters..." -ForegroundColor $Colors.Warning
                kubectl delete imageupdaters --all --all-namespaces --wait=false --ignore-not-found 2>$null
                
                Write-Host "   ✅ CRD instances deleted" -ForegroundColor $Colors.Success
            } catch {
                Write-Host "   ⚠️  Error deleting CRD instances (continuing)" -ForegroundColor $Colors.Warning
            }
            Write-Host ""
            
            # Step 3: Delete ClusterRoles and ClusterRoleBindings (non-system)
            Write-Host "🗑️  Step 4/9: Deleting ClusterRoles/ClusterRoleBindings..." -ForegroundColor $Colors.Info
            $systemPrefixes = @("system:", "kubeadm:", "azure:", "addon-")
            
            try {
                # ClusterRoles
                $clusterRoles = kubectl get clusterroles --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
                foreach ($role in $clusterRoles) {
                    $isSystem = $systemPrefixes | Where-Object { $role -like "$_*" }
                    if (-not $isSystem) {
                        kubectl delete clusterrole $role --ignore-not-found 2>$null
                        Write-Host "   🗑️  ClusterRole: $role" -ForegroundColor $Colors.Muted
                    }
                }
                
                # ClusterRoleBindings
                $clusterRoleBindings = kubectl get clusterrolebindings --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
                foreach ($binding in $clusterRoleBindings) {
                    $isSystem = $systemPrefixes | Where-Object { $binding -like "$_*" }
                    if (-not $isSystem) {
                        kubectl delete clusterrolebinding $binding --ignore-not-found 2>$null
                        Write-Host "   🗑️  ClusterRoleBinding: $binding" -ForegroundColor $Colors.Muted
                    }
                }
                
                Write-Host "   ✅ ClusterRoles/ClusterRoleBindings deleted" -ForegroundColor $Colors.Success
            } catch {
                Write-Host "   ⚠️  Error deleting cluster roles (continuing)" -ForegroundColor $Colors.Warning
            }
            Write-Host ""
            
            # Step 4: Delete ServiceAccounts (non-system)
            Write-Host "🗑️  Step 5/9: Deleting ServiceAccounts..." -ForegroundColor $Colors.Info
            $systemNamespaces = @("kube-system", "kube-public", "kube-node-lease", "default")
            
            try {
                $allNs = kubectl get namespaces --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
                foreach ($ns in $allNs) {
                    if ($ns -notin $systemNamespaces) {
                        $sas = kubectl get serviceaccounts -n $ns --no-headers 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
                        foreach ($sa in $sas) {
                            if ($sa -ne "default") {
                                kubectl delete serviceaccount $sa -n $ns --ignore-not-found 2>$null
                                Write-Host "   🗑️  SA: $ns/$sa" -ForegroundColor $Colors.Muted
                            }
                        }
                    }
                }
                Write-Host "   ✅ ServiceAccounts deleted" -ForegroundColor $Colors.Success
            } catch {
                Write-Host "   ⚠️  Error deleting service accounts (continuing)" -ForegroundColor $Colors.Warning
            }
            Write-Host ""
            
            # Step 5: Delete namespaces
            Write-Host "🗑️  Step 6/9: Deleting namespaces..." -ForegroundColor $Colors.Info
            $namespacesToDelete = @(
                "argocd-image-updater",
                "azure-workload-identity-system",
                "external-secrets",
                "ingress-nginx",
                "cloudgames",
                "argocd"
            )
            
            foreach ($ns in $namespacesToDelete) {
                Write-Host "   🗑️  Namespace: $ns" -ForegroundColor $Colors.Warning
                $nsExists = kubectl get namespace $ns --no-headers 2>$null
                if ($nsExists) {
                    kubectl delete namespace $ns --wait=false 2>$null
                    Write-Host "      ⏳ Deletion initiated" -ForegroundColor $Colors.Muted
                } else {
                    Write-Host "      ⭕ Already absent" -ForegroundColor $Colors.Muted
                }
            }
            
            Write-Host "   ⏳ Waiting for namespaces to terminate (15s)..." -ForegroundColor $Colors.Info
            Start-Sleep -Seconds 15
            
            # Force cleanup of stuck namespaces
            foreach ($ns in $namespacesToDelete) {
                $nsStatus = kubectl get namespace $ns --no-headers 2>$null
                if ($nsStatus -match "Terminating") {
                    Write-Host "      ⚠️  $ns stuck - forcing cleanup..." -ForegroundColor $Colors.Warning
                    kubectl patch namespace $ns -p '{\"spec\":{\"finalizers\":null}}' --type=merge 2>$null
                }
            }
            Write-Host "   ✅ Namespace deletion initiated" -ForegroundColor $Colors.Success
            Write-Host ""
            
            # Step 6: Delete CRDs
            Write-Host "🗑️  Step 7/9: Deleting CRDs..." -ForegroundColor $Colors.Info
            
            $crds = @(
                "applications.argoproj.io",
                "applicationsets.argoproj.io",
                "appprojects.argoproj.io",
                "externalsecrets.external-secrets.io",
                "clustersecretstores.external-secrets.io",
                "secretstores.external-secrets.io",
                "clusterexternalsecrets.external-secrets.io",
                "pushsecrets.external-secrets.io",
                "imageupdaters.argocd-image-updater.argoproj.io",
                "imageupdaterentries.argocd-image-updater.argoproj.io"
            )
            
            foreach ($crd in $crds) {
                try {
                    $exists = kubectl get crd $crd --no-headers 2>$null
                    if ($exists) {
                        kubectl delete crd $crd --ignore-not-found --wait=false 2>$null
                        Write-Host "   ✅ CRD: $crd" -ForegroundColor $Colors.Success
                    }
                } catch {
                    # Continue on error
                }
            }
            Write-Host "   ✅ CRDs deletion initiated" -ForegroundColor $Colors.Success
            Write-Host ""
            
            # Step 7: Check Helm releases
            Write-Host "🗑️  Step 8/9: Checking Helm releases..." -ForegroundColor $Colors.Info
            try {
                $helmReleases = helm list --all-namespaces 2>$null | Select-Object -Skip 1
                if ($helmReleases) {
                    Write-Host "   ℹ️  Remaining releases (will auto-remove with namespaces):" -ForegroundColor $Colors.Muted
                    foreach ($release in $helmReleases) {
                        $parts = $release -split '\s+' | Where-Object { $_ }
                        if ($parts.Count -ge 2) {
                            Write-Host "      • $($parts[0]) in $($parts[1])" -ForegroundColor $Colors.Muted
                        }
                    }
                } else {
                    Write-Host "   ✅ No Helm releases found" -ForegroundColor $Colors.Success
                }
            } catch {
                Write-Host "   ⚠️  Error checking Helm (continuing)" -ForegroundColor $Colors.Warning
            }
            Write-Host ""
            
            # Step 8: Final verification
            Write-Host "🧹 Step 9/9: Final cluster state..." -ForegroundColor $Colors.Info
            
            $allNamespaces = kubectl get namespaces --no-headers 2>$null
            Write-Host "   📋 Namespaces:" -ForegroundColor $Colors.Info
            
            $systemNs = @("default", "kube-system", "kube-public", "kube-node-lease")
            $hasIssues = $false
            
            foreach ($line in $allNamespaces) {
                $nsName = ($line -split '\s+')[0]
                $nsStatus = ($line -split '\s+')[1]
                
                if ($nsName -in $systemNs) {
                    Write-Host "      ✓ $nsName (system)" -ForegroundColor $Colors.Success
                } elseif ($nsStatus -eq "Terminating") {
                    Write-Host "      ⚠️  $nsName (Terminating)" -ForegroundColor $Colors.Warning
                    $hasIssues = $true
                } else {
                    Write-Host "      ! $nsName" -ForegroundColor $Colors.Warning
                    $hasIssues = $true
                }
            }
            
            Write-Host ""
            if ($hasIssues) {
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Warning
                Write-Host "⚠️  Reset completed with warnings" -ForegroundColor $Colors.Warning
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Warning
                Write-Host ""
                Write-Host "Some resources may need manual cleanup:" -ForegroundColor $Colors.Warning
                Write-Host "  • Use: .\force-delete-namespace.ps1 <namespace>" -ForegroundColor $Colors.Muted
                Write-Host "  • Or delete via Azure Portal" -ForegroundColor $Colors.Muted
            } else {
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Success
                Write-Host "✅ Cluster reset complete!" -ForegroundColor $Colors.Success
                Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor $Colors.Success
            }
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor $Colors.Info
            Write-Host "  1. .\aks-manager.ps1 post-terraform-setup" -ForegroundColor $Colors.Muted
            Write-Host "  2. Verify: .\aks-manager.ps1 status" -ForegroundColor $Colors.Muted
            Write-Host ""
        }
        "logs" {
            $component = if ($arg1) { $arg1 } else { "argocd" }
            Write-Host "`n📋 Logs for $component..." -ForegroundColor $Colors.Info
            switch ($component) {
                "argocd" { kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50 }
                "eso" { kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50 }
                "nginx" { kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=50 }
                default { Write-Host "Unknown component: $component" -ForegroundColor $Colors.Error }
            }
        }
        { $_ -in "check-versions", "check-helm-versions" } {
            Write-Host "`n📊 Checking Helm chart versions..." -ForegroundColor $Colors.Info
            $script = Join-Path $scriptPath "check-helm-chart-versions.ps1"
            if (Test-Path $script) {
                & $script
            }
            else {
                Write-Host "❌ Script not found: check-helm-chart-versions.ps1" -ForegroundColor $Colors.Error
            }
        }
        { $_ -in "check-argocd-updates", "check-argocd-versions" } {
            Write-Host "`n🔄 Checking ArgoCD updates..." -ForegroundColor $Colors.Info
            $script = Join-Path $scriptPath "check-argocd-updates.ps1"
            if (Test-Path $script) {
                & $script
            }
            else {
                Write-Host "❌ Script not found: check-argocd-updates.ps1" -ForegroundColor $Colors.Error
            }
        }
        { $_ -in "update-chart", "update-helm-chart" } {
            Write-Host "`n📝 Update Helm chart version..." -ForegroundColor $Colors.Info
            $script = Join-Path $scriptPath "update-helm-chart-version.ps1"
            if (Test-Path $script) {
                Write-Host ""
                Write-Host "Available charts:" -ForegroundColor $Colors.Info
                Write-Host "  1. ingress-nginx" -ForegroundColor $Colors.Muted
                Write-Host "  2. external-secrets" -ForegroundColor $Colors.Muted
                Write-Host "  3. workload-identity-webhook" -ForegroundColor $Colors.Muted
                Write-Host ""
                
                $chartInput = Read-Host "Chart name or number (1-3)"
                
                # Map number to chart name
                $chartMap = @{
                    "1" = "ingress-nginx"
                    "2" = "external-secrets"
                    "3" = "workload-identity-webhook"
                }
                
                $chartName = if ($chartMap.ContainsKey($chartInput)) {
                    $chartMap[$chartInput]
                } else {
                    $chartInput
                }
                
                $version = Read-Host "Target version"
                
                if ($chartName -and $version) {
                    & $script -Chart $chartName -Version $version
                }
                else {
                    Write-Host "❌ Chart name and version are required" -ForegroundColor $Colors.Error
                }
            }
            else {
                Write-Host "❌ Script not found: update-helm-chart-version.ps1" -ForegroundColor $Colors.Error
            }
        }
        "cleanup-audit" {
            Write-Host "`n🔍 Running cleanup audit..." -ForegroundColor $Colors.Info
            $script = Join-Path $scriptPath "cluster-cleanup-audit.ps1"
            if (Test-Path $script) {
                & $script
            }
            else {
                Write-Host "❌ Script not found: cluster-cleanup-audit.ps1" -ForegroundColor $Colors.Error
            }
        }
        { $_ -in "force-delete-ns", "force-delete-namespace" } {
            if ($arg1) {
                Write-Host "`n🗑️  Force deleting namespace: $arg1" -ForegroundColor $Colors.Warning
                $script = Join-Path $scriptPath "force-delete-namespace.ps1"
                if (Test-Path $script) {
                    & $script $arg1
                }
                else {
                    Write-Host "❌ Script not found: force-delete-namespace.ps1" -ForegroundColor $Colors.Error
                }
            } else {
                Write-Host "`n📋 Checking for terminating namespaces..." -ForegroundColor $Colors.Info
                $script = Join-Path $scriptPath "force-delete-namespace.ps1"
                if (Test-Path $script) {
                    & $script
                }
                else {
                    Write-Host "❌ Script not found: force-delete-namespace.ps1" -ForegroundColor $Colors.Error
                }
            }
        }
        "fix-argocd-sync" {
            Write-Host "`n🔄 Running ArgoCD sync recovery..." -ForegroundColor $Colors.Info
            $script = Join-Path $scriptPath "fix-argocd-sync.ps1"
            if (Test-Path $script) {
                & $script
            }
            else {
                Write-Host "❌ Script not found: fix-argocd-sync.ps1" -ForegroundColor $Colors.Error
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
