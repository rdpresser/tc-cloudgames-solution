<#
.SYNOPSIS
  Verifica conectividade de rede do Docker antes de criar cluster k3d.
.DESCRIPTION
  Este script diagnostica problemas comuns de rede do Docker Desktop no Windows
  que podem impedir o cluster k3d de funcionar corretamente.
#>

Write-Host "`n=== Docker Network Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# 1) Verificar se Docker está rodando
Write-Host "1️⃣ Verificando Docker..." -ForegroundColor Cyan
try {
    docker version | Out-Null
    Write-Host "   ✅ Docker está ativo" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Docker não está rodando!" -ForegroundColor Red
    Write-Host "   Inicie o Docker Desktop primeiro." -ForegroundColor Yellow
    exit 1
}

# 2) Verificar conectividade de rede básica
Write-Host "`n2️⃣ Verificando conectividade de containers..." -ForegroundColor Cyan
try {
    $testResult = docker run --rm alpine ping -c 2 google.com 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Containers conseguem acessar a internet" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Containers têm problemas de conectividade" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Não foi possível testar conectividade de containers" -ForegroundColor Yellow
}

# 3) Verificar host.docker.internal
Write-Host "`n3️⃣ Verificando host.docker.internal..." -ForegroundColor Cyan
try {
    $hostResolution = docker run --rm alpine nslookup host.docker.internal 2>&1
    if ($hostResolution -match "Address") {
        Write-Host "   ✅ host.docker.internal resolve corretamente" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  host.docker.internal não resolve" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Não foi possível verificar host.docker.internal" -ForegroundColor Yellow
}

# 4) Verificar configurações WSL2 (se aplicável)
Write-Host "`n4️⃣ Verificando modo de backend do Docker..." -ForegroundColor Cyan
$dockerInfo = docker info 2>&1 | Out-String
if ($dockerInfo -match "WSL") {
    Write-Host "   ℹ️  Docker usando WSL2 backend" -ForegroundColor Cyan
    Write-Host "   Se houver problemas, considere:" -ForegroundColor Gray
    Write-Host "   - Reiniciar WSL: wsl --shutdown" -ForegroundColor Gray
    Write-Host "   - Reiniciar Docker Desktop" -ForegroundColor Gray
} else {
    Write-Host "   ℹ️  Docker usando Hyper-V backend" -ForegroundColor Cyan
}

# 5) Verificar recursos disponíveis
Write-Host "`n5️⃣ Verificando recursos do Docker..." -ForegroundColor Cyan
$cpus = (docker info --format '{{.NCPU}}' 2>$null)
$memory = (docker info --format '{{.MemTotal}}' 2>$null)

if ($cpus) {
    Write-Host "   CPUs: $cpus" -ForegroundColor White
}
if ($memory) {
    $memoryGB = [math]::Round($memory / 1GB, 2)
    Write-Host "   Memória: $memoryGB GB" -ForegroundColor White
    
    if ($memoryGB -lt 16) {
        Write-Host "   ⚠️  Recomendado: pelo menos 16GB para este cluster" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Memória suficiente" -ForegroundColor Green
    }
}

# 6) Verificar portas necessárias
Write-Host "`n6️⃣ Verificando portas necessárias..." -ForegroundColor Cyan
$ports = @(80, 443, 8080, 3000)
$portsInUse = @()

foreach ($port in $ports) {
    $connection = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($connection) {
        $portsInUse += $port
    }
}

if ($portsInUse.Count -gt 0) {
    Write-Host "   ⚠️  Portas em uso: $($portsInUse -join ', ')" -ForegroundColor Yellow
    Write-Host "   Execute .\stop-port-forward.ps1 para liberar portas 8080/3000" -ForegroundColor Gray
} else {
    Write-Host "   ✅ Todas as portas necessárias estão livres" -ForegroundColor Green
}

# Resumo
Write-Host "`n=== Resumo ===" -ForegroundColor Cyan
Write-Host "Se todos os checks passaram, você pode criar o cluster:" -ForegroundColor White
Write-Host "   .\create-all-from-zero.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "Se houver problemas:" -ForegroundColor Yellow
Write-Host "   1. Reinicie o Docker Desktop" -ForegroundColor Gray
Write-Host "   2. Se usar WSL2, execute: wsl --shutdown" -ForegroundColor Gray
Write-Host "   3. Aguarde o Docker iniciar completamente" -ForegroundColor Gray
Write-Host "   4. Execute este script novamente" -ForegroundColor Gray
Write-Host ""
