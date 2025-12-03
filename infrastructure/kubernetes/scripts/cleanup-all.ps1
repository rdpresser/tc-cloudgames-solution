<#
.SYNOPSIS
  Limpa ambiente local: apaga clusters k3d, registry local (se existir), e remove headlamp container.
#>

# Lista de clusters a remover (ajuste se tiver outros)
$clusters = @("dev")
$registryName = "k3d-registry.local"

# 0) Parar port-forwards (CRITICAL: Liberar portas 8090/3000)
Write-Host "=== 0) Parando port-forwards ==="
if (Test-Path ".\stop-port-forward.ps1") {
    .\stop-port-forward.ps1 all
} else {
    Write-Host "Script stop-port-forward.ps1 não encontrado. Tentando matar kubectl port-forward manualmente..."
    Get-Process kubectl -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
            if ($cmd -match "port-forward") {
                Stop-Process -Id $_.Id -Force
                Write-Host "Processo kubectl port-forward ($($_.Id)) finalizado."
            }
        } catch {}
    }
}

# 1) Stop & remove headlamp container (se existir)
Write-Host "Removendo Headlamp container se existir..."
docker ps -a --filter "name=headlamp" --format "{{.ID}}\t{{.Names}}" | ForEach-Object {
    $id = ($_ -split "`t")[0]
    docker rm -f $id 2>$null | Out-Null
}

# 2) Delete clusters
foreach ($c in $clusters) {
    Write-Host "Deletando cluster $c (se existir)..."
    k3d cluster list | Select-String -Pattern "^$c\s" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        k3d cluster delete $c
    } else {
        Write-Host "Cluster $c não existe. Pulando."
    }
}

# 3) Remove registry (se existir)
Write-Host "Verificando registry $registryName..."
$regList = k3d registry list
if ($regList -match $registryName) {
    Write-Host "Removendo registry $registryName..."
    k3d registry delete $registryName
} else {
    Write-Host "Registry não encontrado. Pulando."
}

# 4) Opcional: remove helm releases locais (não aplicável após cluster delete)
Write-Host "Limpeza concluída. Verifique docker ps -a e k3d cluster list para confirmar."
