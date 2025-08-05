Write-Host "Cloning TC-CloudGames repositories with aliases..."
Write-Host ""
Write-Host ""

$repos = @(
    @{ name = "tc-cloudgames-infra"; alias = "infra"; folder = "infrastructure" },
    @{ name = "tc-cloudgames-apphost"; alias = "apphost"; folder = "orchestration" },
    @{ name = "tc-cloudgames-users"; alias = "users"; folder = "services" },
    @{ name = "tc-cloudgames-games"; alias = "games"; folder = "services" },
    @{ name = "tc-cloudgames-payments"; alias = "payments"; folder = "services" },
    @{ name = "tc-cloudgames-common"; alias = "common"; folder = "shared" },
    @{ name = "tc-cloudgames-pipelines"; alias = "pipelines"; folder = "automation" }
)

$githubUser = "rdpresser"

# Go back one level to the root directory
Set-Location ..

# Create organizational directories if they don't exist
$organizationalFolders = @("infrastructure", "orchestration", "services", "shared", "automation")
foreach ($orgFolder in $organizationalFolders) {
    if (-not (Test-Path $orgFolder)) {
        New-Item -ItemType Directory -Path $orgFolder -Force
        Write-Host "Created directory: $orgFolder"
    }
}

Write-Host ""
Write-Host ""

foreach ($repo in $repos) {
    $url = "https://github.com/$githubUser/$($repo.name).git"
    $alias = $repo.alias
    $parentFolder = $repo.folder
    $targetPath = "$parentFolder/$alias"
    
    Write-Host "Cloning $($repo.name) as $targetPath..."
    git clone $url $targetPath
}

Write-Host ""
Write-Host ""
Write-Host "All repositories have been cloned with their aliases."
