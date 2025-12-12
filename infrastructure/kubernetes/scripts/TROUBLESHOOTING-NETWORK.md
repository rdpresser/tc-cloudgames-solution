# 🔧 Problema: Cluster K3D não conecta após criação

## ❌ Sintoma
- Cluster k3d é criado com sucesso
- Comando `kubectl get nodes` falha com erro:
  ```
  dial tcp 192.168.0.25:XXXXX: connectex: A connection attempt failed...
  ```
- Erro ocorre com `host.docker.internal`

## 🔍 Causa
Problema de resolução DNS do Windows com WSL2 após muito tempo ligado ou com mudanças de rede.

## ✅ Solução Rápida

### Opção 1: Reiniciar WSL2 (Recomendado)
```powershell
# 1. Feche TODOS os terminais/VS Code que usam WSL

# 2. Abra PowerShell como Administrador e execute:
wsl --shutdown

# 3. Aguarde 10 segundos

# 4. Abra Docker Desktop e aguarde iniciar completamente

# 5. Execute o diagnóstico:
.\check-docker-network.ps1

# 6. Se tudo OK, recrie o cluster:
.\create-all-from-zero.ps1
```

### Opção 2: Reiniciar Docker Desktop
```powershell
# 1. Clique com botão direito no ícone do Docker Desktop (system tray)
# 2. Selecione "Restart Docker Desktop"
# 3. Aguarde iniciar completamente
# 4. Execute:
.\create-all-from-zero.ps1
```

### Opção 3: Reiniciar Windows (Se opções 1 e 2 falharem)
```powershell
# Simplesmente reinicie o computador
# Após reiniciar:
.\start-cluster.ps1  # Se o cluster já existia
# OU
.\create-all-from-zero.ps1  # Se precisa criar novo
```

## 🛡️ Prevenção

### Criar Cluster Corretamente desde o início:
```powershell
# 1. Reinicie Docker Desktop OU execute wsl --shutdown
# 2. Aguarde Docker estar completamente pronto
# 3. Execute diagnóstico:
.\check-docker-network.ps1

# 4. Se tudo OK, crie o cluster:
.\create-all-from-zero.ps1
```

## 🔧 Correção Manual (Se script falhar)

Se o script criar o cluster mas kubectl não conectar:

```powershell
# 1. Obter a porta do cluster
$port = (docker port k3d-dev-serverlb 6443/tcp).Split(':')[-1]

# 2. Atualizar kubeconfig
kubectl config set-cluster k3d-dev --server="https://127.0.0.1:$port"

# 3. Testar
kubectl get nodes
```

## 📝 Notas Técnicas

- O k3d usa `host.docker.internal` por padrão no Windows
- WSL2 às vezes falha ao resolver este hostname corretamente
- Usar `127.0.0.1` resolve o problema
- O script `create-all-from-zero.ps1` agora faz isso automaticamente

## ⚠️ Se NADA funcionar:

```powershell
# Limpeza completa:
.\cleanup-all.ps1
k3d registry delete registry.local
docker system prune -a --volumes -f

# Reiniciar WSL:
wsl --shutdown

# Reiniciar Docker Desktop

# Aguardar 1-2 minutos

# Recriar tudo:
.\create-all-from-zero.ps1
```

## 🆘 Logs Úteis

```powershell
# Ver logs do servidor k3d:
docker logs k3d-dev-server-0

# Ver logs do serverlb:
docker logs k3d-dev-serverlb

# Testar conectividade direta:
docker exec -it k3d-dev-server-0 kubectl get nodes
```
