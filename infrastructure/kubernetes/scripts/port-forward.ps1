<#
.SYNOPSIS
  Starts port-forward for ArgoCD and/or Grafana in background (detached) mode.
.DESCRIPTION
  Script to facilitate access to k3d cluster services via port-forward.
  Runs in background without blocking the terminal.

  Available services:
  - argocd: http://localhost:8090 (redirects to ArgoCD port 443 - HTTP Insecure)
  - grafana: http://localhost:3000 (redirects to Grafana port 80)
  - all: Starts both port-forwards

.PARAMETER Service
  Service for port-forward: argocd, grafana, or all

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

# Function to check if port-forward is already running
function Test-PortForwardRunning($port, $serviceName) {
    # First check if port is in use
    $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($connections.Count -eq 0) {
        return $false
    }

    # Check if it's a kubectl port-forward for this specific service
    $kubectlProcs = Get-Process -Name kubectl -ErrorAction SilentlyContinue
    if (-not $kubectlProcs) {
        # Port in use but not kubectl - consider as free for our purposes
        return $false
    }

    foreach ($proc in $kubectlProcs) {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
            # Check if it's port-forward AND has the specific service AND uses the correct local port
            if ($cmdLine -and
                $cmdLine -like "*port-forward*" -and
                $cmdLine -like "*svc/$serviceName*" -and
                $cmdLine -match "(\d+):") {

                $localPort = $matches[1]
                if ($localPort -eq $port) {
                    Write-Host "   ℹ️  Found existing process: PID $($proc.Id)" -ForegroundColor Gray
                    return $true
                }
            }
        } catch {
            continue
        }
    }

    return $false
}

# Function to start port-forward in background
function Start-PortForward($serviceName, $namespace, $port, $targetPort, $kubectlPath) {
    $portNumber = $port

    # Check if port-forward already exists for this service on this port
    if (Test-PortForwardRunning $portNumber $serviceName) {
        Write-Host "⚠️  Port-forward for $serviceName is already running on port $portNumber" -ForegroundColor Yellow
        return $null
    }

    Write-Host "🚀 Starting port-forward for $serviceName..." -ForegroundColor Cyan
    Write-Host "   📡 Accessible at: http://localhost:$port" -ForegroundColor Green
    Write-Host "   🔧 Using: $kubectlPath" -ForegroundColor Gray

    # Start process in background using full kubectl path
    $process = Start-Process -FilePath $kubectlPath `
        -ArgumentList "port-forward", "svc/$serviceName", "-n", "$namespace", "${port}:${targetPort}", "--address", "0.0.0.0" `
        -WindowStyle Hidden `
        -PassThru

    Write-Host "   ⏳ Process started: PID $($process.Id)" -ForegroundColor Gray

    # Wait a moment to ensure port-forward is active
    Start-Sleep -Seconds 3

    # Check if process is still running
    if ($process.HasExited) {
        Write-Host "❌ Failed to start port-forward for $serviceName" -ForegroundColor Red
        Write-Host "   The process terminated immediately. Check if the service exists in the cluster." -ForegroundColor Yellow
        return $null
    }

    # Validate if the port is actually listening
    $portCheck = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if (-not $portCheck) {
        Write-Host "❌ Port-forward started but port $port is not listening" -ForegroundColor Red
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        return $null
    }

    Write-Host "✅ Port-forward for $serviceName started (PID: $($process.Id))" -ForegroundColor Green
    return $process
}

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: kubectl not found in PATH" -ForegroundColor Red
    exit 1
}

# Get the full kubectl path
# If it's a Chocolatey shim, use the real executable
$kubectlCmd = Get-Command kubectl
$kubectlPath = $kubectlCmd.Source

# Check if it's a Chocolatey shim and use the real executable
if ($kubectlPath -like "*chocolatey\bin\kubectl.exe") {
    $realPath = "C:\ProgramData\chocolatey\lib\kubernetes-cli\tools\kubernetes\client\bin\kubectl.exe"
    if (Test-Path $realPath) {
        $kubectlPath = $realPath
        Write-Host "ℹ️  Using real kubectl (not the shim): $kubectlPath" -ForegroundColor Gray
    }
}

Write-Host "`n=== Port-Forward Manager ===" -ForegroundColor Cyan
Write-Host "Mode: $Service`n" -ForegroundColor White

$processes = @()

# Start port-forwards as requested
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
    Write-Host "`n⚠️  No port-forward was started" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n" -NoNewline
Write-Host "📌 Active port-forwards:" -ForegroundColor Cyan
if ($Service -eq "argocd" -or $Service -eq "all") {
    Write-Host "   🔐 ArgoCD:  http://localhost:8090" -ForegroundColor Green
}
if ($Service -eq "grafana" -or $Service -eq "all") {
    Write-Host "   📊 Grafana: http://localhost:3000" -ForegroundColor Green
}

Write-Host "`n💡 To stop port-forwards, run: .\stop-port-forward.ps1`n" -ForegroundColor Yellow
