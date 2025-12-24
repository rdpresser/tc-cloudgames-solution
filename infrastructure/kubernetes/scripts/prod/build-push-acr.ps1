<#
.SYNOPSIS
  Build and push Docker images for CloudGames APIs to Azure Container Registry (ACR).

.DESCRIPTION
  Builds Docker images for user-api, games-api, and payments-api,
  tags them for ACR, and pushes them to Azure Container Registry.
  Supports authentication via Azure CLI or existing docker login.

.PARAMETER Api
  Specific API to build: user, games, payments, or all (default).

.PARAMETER Tag
  Image tag to use. Default: dev

.PARAMETER AcrName
  Azure Container Registry name. Default: tccloudgamesdevcr8nacr

.PARAMETER SkipPush
  Build only, skip push to ACR.

.PARAMETER SkipLogin
  Skip ACR login (assumes already authenticated).

.EXAMPLE
  .\build-push-acr.ps1
  # Builds and pushes all APIs with tag 'dev'

.EXAMPLE
  .\build-push-acr.ps1 -Api user -Tag v1.0.0
  # Builds and pushes only user-api with tag v1.0.0

.EXAMPLE
  .\build-push-acr.ps1 -AcrName myregistry -Tag prod
  # Builds and pushes to custom ACR with tag 'prod'
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("all", "user", "games", "payments")]
    [string]$Api = "all",

    [Parameter()]
    [string]$Tag = "dev",

    [Parameter()]
    [string]$AcrName = "tccloudgamesdevcr8nacr",

    [Parameter()]
    [switch]$SkipPush,

    [Parameter()]
    [switch]$SkipLogin
)

$ErrorActionPreference = "Stop"

$script:Colors = @{
    Title   = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
    Info    = "White"
    Muted   = "Gray"
}

$script:AcrLoginServer = "${AcrName}.azurecr.io"

function Get-BuildTags {
    param([string]$RequestedTag)

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $gitSha = "local"
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
    try {
        Push-Location $repoRoot
        $gitSha = git rev-parse --short=8 HEAD 2>$null
        if (-not $gitSha) { $gitSha = "local" }
    }
    catch { $gitSha = "local" }
    finally { Pop-Location }

    $generatedTag = "$timestamp-$gitSha"

    # Always publish two tags: latest and timestamp-sha
    return @($generatedTag, "latest")
}

# API configurations
$script:Apis = @{
    "user" = @{
        Name = "users-api"
        Dockerfile = "services/users/src/Adapters/Inbound/TC.CloudGames.Users.Api/Dockerfile"
    }
    "games" = @{
        Name = "games-api"
        Dockerfile = "services/games/src/Adapters/Inbound/TC.CloudGames.Games.Api/Dockerfile"
    }
    "payments" = @{
        Name = "payms-api"
        Dockerfile = "services/payments/src/Adapters/Inbound/TC.CloudGames.Payments.Api/Dockerfile"
    }
}

function Show-Header {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor $Colors.Title
    Write-Host "    Docker Build & Push - CloudGames APIs to ACR        " -ForegroundColor $Colors.Title
    Write-Host "========================================================" -ForegroundColor $Colors.Title
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host "=== 1/5 Checking prerequisites ===" -ForegroundColor $Colors.Title
    
    # Check Docker
    try {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Docker not running" }
        Write-Host "✅ Docker is running" -ForegroundColor $Colors.Success
    } catch {
        Write-Host "❌ Docker is not running or not installed." -ForegroundColor $Colors.Error
        exit 1
    }

    # Check Azure CLI
    if (-not $SkipLogin) {
        try {
            $azAccount = az account show 2>$null | ConvertFrom-Json
            if (-not $azAccount) { throw "Not logged in" }
            Write-Host "✅ Azure CLI logged in as: $($azAccount.user.name)" -ForegroundColor $Colors.Success
        } catch {
            Write-Host "❌ Azure CLI not logged in." -ForegroundColor $Colors.Error
            Write-Host "   Run: az login" -ForegroundColor $Colors.Warning
            exit 1
        }
    }

    Write-Host ""
}

function Connect-ACR {
    if ($SkipLogin) {
        Write-Host "⏭️  Skipping ACR login (--SkipLogin specified)" -ForegroundColor $Colors.Muted
        return
    }

    Write-Host "=== 2/5 Authenticating to ACR ===" -ForegroundColor $Colors.Title
    Write-Host "Logging in to $AcrLoginServer..." -ForegroundColor $Colors.Info
    
    az acr login --name $AcrName 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to login to ACR: $AcrName" -ForegroundColor $Colors.Error
        Write-Host "   Verify ACR exists and you have permissions" -ForegroundColor $Colors.Warning
        exit 1
    }
    
    Write-Host "✅ Authenticated to $AcrLoginServer" -ForegroundColor $Colors.Success
    Write-Host ""
}

function Build-Api {
    param([string]$ApiKey)
    
    $apiConfig = $Apis[$ApiKey]
    $imageName = $apiConfig.Name
    $dockerfile = $apiConfig.Dockerfile
    $tags = Get-BuildTags -RequestedTag $Tag
    $primaryTag = $tags[0]
    $primaryImage = "${AcrLoginServer}/${imageName}:${primaryTag}"
    
    Write-Host "Building $imageName..." -ForegroundColor $Colors.Info
    
    # Get repository root - navigate from infrastructure/kubernetes/scripts/prod/ to project root
    $repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
    $dockerfilePath = Join-Path $repoRoot $dockerfile

    if (-not (Test-Path $dockerfilePath)) {
        Write-Host "❌ Dockerfile not found: $dockerfile" -ForegroundColor $Colors.Error
        return $false
    }

    # Build with repository root as context (includes shared/ and services/)
    Write-Host "   Dockerfile: $dockerfile" -ForegroundColor $Colors.Muted
    Write-Host "   Context: $repoRoot" -ForegroundColor $Colors.Muted
    Write-Host "   Tags: $($tags -join ', ')" -ForegroundColor $Colors.Muted
    
    docker build -t $primaryImage -f $dockerfilePath $repoRoot 2>&1
    $buildResult = $LASTEXITCODE

    if ($buildResult -ne 0) {
        Write-Host "❌ Build failed for $imageName" -ForegroundColor $Colors.Error
        return $false
    }
    Write-Host "✅ Built $primaryImage" -ForegroundColor $Colors.Success

    # Tag additional tags pointing to same image
    foreach ($tag in $tags) {
        if ($tag -eq $primaryTag) { continue }
        $targetImage = "${AcrLoginServer}/${imageName}:${tag}"
        docker tag $primaryImage $targetImage
        Write-Host "   Tagged: $targetImage" -ForegroundColor $Colors.Muted
    }

    # Push to ACR
    if (-not $SkipPush) {
        foreach ($tag in $tags) {
            $targetImage = "${AcrLoginServer}/${imageName}:${tag}"
            Write-Host "   Pushing: $targetImage" -ForegroundColor $Colors.Muted
            docker push $targetImage 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Push failed for $targetImage" -ForegroundColor $Colors.Error
                return $false
            }
            Write-Host "✅ Pushed $targetImage" -ForegroundColor $Colors.Success
        }
    }

    Write-Host ""
    return $true
}

# Main execution
Show-Header
Test-Prerequisites
Connect-ACR

# Determine which APIs to build
$apisToBuild = @()
if ($Api -eq "all") {
    $apisToBuild = @("user", "games", "payments")
} else {
    $apisToBuild = @($Api)
}

Write-Host "=== 3/5 Building Docker images ===" -ForegroundColor $Colors.Title
Write-Host "   APIs: $($apisToBuild -join ', ')" -ForegroundColor $Colors.Info
Write-Host "   Tag: $Tag" -ForegroundColor $Colors.Info
Write-Host "   Registry: $AcrLoginServer" -ForegroundColor $Colors.Info
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($apiKey in $apisToBuild) {
    $result = Build-Api -ApiKey $apiKey
    if ($result) {
        $successCount++
    } else {
        $failCount++
    }
}

# Summary
Write-Host "=== 4/5 Summary ===" -ForegroundColor $Colors.Title
Write-Host "   ✅ Built: $successCount" -ForegroundColor $Colors.Success
if ($failCount -gt 0) {
    Write-Host "   ❌ Failed: $failCount" -ForegroundColor $Colors.Error
}
if (-not $SkipPush) {
    Write-Host "   📦 Pushed to: $AcrLoginServer" -ForegroundColor $Colors.Info
}
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "=== 5/5 Next Steps ===" -ForegroundColor $Colors.Title
    Write-Host "✅ All images built and pushed successfully!" -ForegroundColor $Colors.Success
    Write-Host ""
    Write-Host "To update deployments in AKS:" -ForegroundColor $Colors.Info
    Write-Host "   kubectl set image deployment/user-api user-api=$AcrLoginServer/users-api:$Tag -n cloudgames" -ForegroundColor $Colors.Muted
    Write-Host "   kubectl set image deployment/games-api games-api=$AcrLoginServer/games-api:$Tag -n cloudgames" -ForegroundColor $Colors.Muted
    Write-Host "   kubectl set image deployment/payments-api payments-api=$AcrLoginServer/payms-api:$Tag -n cloudgames" -ForegroundColor $Colors.Muted
    Write-Host ""
    Write-Host "Or restart deployments to pull new images:" -ForegroundColor $Colors.Info
    Write-Host "   kubectl rollout restart deployment -n cloudgames" -ForegroundColor $Colors.Muted
} else {
    Write-Host "❌ Some builds failed. Check errors above." -ForegroundColor $Colors.Warning
    exit 1
}
Write-Host ""
