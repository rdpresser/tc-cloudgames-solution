# Caminho temporário para armazenar o kubeconfig compatível com o container
$kubeTemp = "$env:TEMP\kubeconfig-headlamp"

# 1️⃣ Gera uma cópia completa do kubeconfig atual
# O --raw mantém os tokens e certificados originais
kubectl config view --raw | Out-File -FilePath $kubeTemp -Encoding utf8

# 2️⃣ Verifica se o arquivo foi gerado corretamente
if (-Not (Test-Path $kubeTemp)) {
    Write-Host "❌ Erro: não foi possível gerar o kubeconfig temporário." -ForegroundColor Red
    exit 1
}

# 3️⃣ Mostra o caminho e garante permissões de leitura (não precisa chmod no Windows)
Write-Host "✅ Arquivo kubeconfig temporário criado em: $kubeTemp" -ForegroundColor Green

# 4️⃣ Para e remove qualquer container anterior do Headlamp
docker stop headlamp 2>$null | Out-Null
docker rm headlamp 2>$null | Out-Null

# 5️⃣ Inicia o container Headlamp apontando para o kubeconfig temporário
docker run -d `
  --name headlamp `
  -p 4466:4466 `
  -v "${kubeTemp}:/root/.kube/config:ro" `
  -e KUBECONFIG=/root/.kube/config `
  ghcr.io/headlamp-k8s/headlamp:latest | Out-Null

# 6️⃣ Aguarda o backend do Headlamp subir
Write-Host "🚀 Iniciando Headlamp... aguarde alguns segundos." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# 7️⃣ Abre automaticamente no navegador padrão
Start-Process "http://localhost:4466"

# 8️⃣ Mostra o status do container
docker ps --filter "name=headlamp"
