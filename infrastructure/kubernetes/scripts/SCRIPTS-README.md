# 🚀 K3D Cluster Management Scripts

> Use **k3d-manager.ps1** for all common tasks (interactive menu + CLI).

## ⚡ Quick Start
```powershell
# Interactive menu
.\k3d-manager.ps1

# Help
.\k3d-manager.ps1 --help

# Direct commands
.\k3d-manager.ps1 status
.\k3d-manager.ps1 create
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all
.\k3d-manager.ps1 headlamp
```

## 🎯 Recommended Flow
```powershell
# First time
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all
.\k3d-manager.ps1 headlamp   # optional UI

# After reboot
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all

# Status
.\k3d-manager.ps1 status
.\k3d-manager.ps1 list
```

## 📦 Scripts Overview
- `k3d-manager.ps1` (main): menu + CLI, wraps all scripts (create, start, cleanup, port-forward, stop, list, check, headlamp, status, help/menu).
- `create-all-from-zero.ps1`: full cluster build (registry, cluster, Argo CD, KEDA, Prometheus+Grafana, sets Argo CD password `Argo@123`, Grafana user `rdpresser/rdpresser@123`).
- `start-cluster.ps1`: start existing cluster after reboot (checks Docker, sets kube context, waits core pods).
- `port-forward.ps1`: start port-forwards (Argo CD 8090->443, Grafana 3000->80) in background with duplicate checks.
- `stop-port-forward.ps1`: stop specific or all port-forward processes.
- `list-port-forward.ps1`: list active port-forwards.
- `cleanup-all.ps1`: remove everything (cluster + registry).
- `check-docker-network.ps1`: diagnose Docker/network issues.
- `start-headlamp-docker.ps1`: start Headlamp UI container.

## 🔗 Services
| Service  | URL                   | Credentials |
|----------|-----------------------|-------------|
| Argo CD  | http://localhost:8090 | admin / Argo@123 |
| Grafana  | http://localhost:3000 | rdpresser / rdpresser@123 |
| Headlamp | http://localhost:4466 | kubeconfig |

## 🏗️ Build & Push Images (k3d registry) {#build-push-images}
```powershell
cd C:\Projects\tc-cloudgames-solution

# Build
docker build -t user-api:dev     -f services\users\src\Adapters\Inbound\TC.CloudGames.Users.Api\Dockerfile .
docker build -t games-api:dev    -f services\games\src\Adapters\Inbound\TC.CloudGames.Games.Api\Dockerfile .
docker build -t payments-api:dev -f services\payments\src\Adapters\Inbound\TC.CloudGames.Payments.Api\Dockerfile .

# Tag for k3d registry
docker tag user-api:dev     localhost:5000/user-api:dev
docker tag games-api:dev    localhost:5000/games-api:dev
docker tag payments-api:dev localhost:5000/payments-api:dev

# Push
docker push localhost:5000/user-api:dev
docker push localhost:5000/games-api:dev
docker push localhost:5000/payments-api:dev
```

### Alternate: Import images (no registry pull)
```powershell
k3d image import user-api:dev games-api:dev payments-api:dev -c dev
kubectl rollout restart deployment user-api     -n cloudgames-dev
kubectl rollout restart deployment games-api    -n cloudgames-dev
kubectl rollout restart deployment payments-api -n cloudgames-dev
```

## 🛠️ Troubleshooting
- Port-forward issues: `./k3d-manager.ps1 stop all` then `./k3d-manager.ps1 port-forward all`
- Cluster stopped after reboot: `./k3d-manager.ps1 start`
- Docker/network issues: `./k3d-manager.ps1 check`
- Full reset: `./k3d-manager.ps1 cleanup` then recreate

## 💡 Tips
- Add alias in PowerShell profile: `Set-Alias k3d "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\k3d-manager.ps1"`
- Use `k3d` to open menu, `k3d status`, `k3d create`, `k3d port-forward all`.

## 🔗 Related Guides

- **Grafana Cloud Integration (AKS)**: For production AKS monitoring, see [Grafana Agent Setup](../../terraform/modules/grafana_agent/README.md).
  - [Why Azure Monitor + Grafana Agent](../../terraform/modules/grafana_agent/README.md#executive-summary)
  - [Obtain Grafana Cloud Credentials](../../terraform/modules/grafana_agent/README.md#credentials)

.\stop-port-forward.ps1
.\stop-port-forward.ps1 all

# Parar apenas ArgoCD
.\stop-port-forward.ps1 argocd

# Parar apenas Grafana
.\stop-port-forward.ps1 grafana
```

---

### 4️⃣ **`list-port-forward.ps1`** 📋

**Função**: Lista port-forwards em execução com detalhes.

**O que faz:**
- Mostra todos os processos kubectl port-forward ativos
- Exibe PID, serviço, porta e tempo de execução (uptime)
- Útil para monitoramento e troubleshooting

**Uso:**
```powershell
.\list-port-forward.ps1
```

**Saída exemplo:**
```
=== Port-Forwards Ativos ===

🔗 Port-Forward Ativo:
   Serviço: argocd-server
   Porta:   http://localhost:8090
   PID:     12345
   Uptime:  00:15:32

🔗 Port-Forward Ativo:
   Serviço: kube-prom-stack-grafana
   Porta:   http://localhost:3000
   PID:     12346
   Uptime:  00:15:30
```

---

### 4.1️⃣ **`check-docker-network.ps1`** 🔍

**Função**: Diagnostica problemas de rede do Docker antes de criar cluster.

**O que faz:**
- Verifica se Docker está rodando
- Testa conectividade de containers
- Valida resolução de `host.docker.internal`
- Identifica modo de backend (WSL2/Hyper-V)
- Verifica recursos disponíveis (CPU/RAM)
- Checa portas necessárias (80, 443, 8090, 3000)

**Uso:**
```powershell
.\check-docker-network.ps1
# ou via manager
.\k3d-manager.ps1 check
```

**Quando usar:**
- ✅ Antes de criar o cluster pela primeira vez
- ✅ Após problemas de conectividade
- ✅ Quando kubectl não conecta ao cluster
- ✅ Após mudanças no Docker Desktop

---

### 4.2️⃣ **`start-headlamp-docker.ps1`** 🎨

**Função**: Inicia Headlamp Kubernetes UI em container Docker.

**O que faz:**
- Gera kubeconfig temporário compatível
- Remove container anterior se existir
- Inicia Headlamp na porta 4466
- Configura acesso ao cluster k3d

**Uso:**
```powershell
.\start-headlamp-docker.ps1
# ou via manager
.\k3d-manager.ps1 headlamp
```

**Acesso:**
- **URL**: http://localhost:4466
- Interface gráfica para gerenciar o cluster k3d

**Características:**
- ✅ UI moderna para Kubernetes
- ✅ Visualização de recursos
- ✅ Logs e métricas
- ✅ Gerenciamento simplificado

---

### 5️⃣ **`cleanup-all.ps1`** 🗑️

**Função**: Remove completamente o cluster e recursos.

**O que faz:**
- Para todos os port-forwards
- Remove container Headlamp
- Deleta cluster k3d
- Remove registry local (opcional)

**Uso:**
```powershell
.\cleanup-all.ps1
# ou via manager
.\k3d-manager.ps1 cleanup
```

**Quando usar:**
- ✅ Para começar do zero
- ✅ Liberar recursos do sistema
- ✅ Resolver problemas persistentes
- ⚠️ ATENÇÃO: Remove todos os dados do cluster

---

## 🎯 Workflow Típico

### 🆕 Primeira vez:
```powershell
# Opção 1: Via manager (recomendado)
.\k3d-manager.ps1
# Escolha opção 1 (Criar cluster)
# Depois opção 3 (Port-forward todos)

# Opção 2: Via linha de comando
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all

# Opção 3: Scripts diretos
.\create-all-from-zero.ps1
.\port-forward.ps1 all
```

### 🔄 Após reiniciar o computador:
```powershell
# Via manager (recomendado)
.\k3d-manager.ps1
# Escolha opção 2 (Iniciar cluster)
# Depois opção 3 (Port-forward todos)

# Via linha de comando
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all

# Scripts diretos
.\start-cluster.ps1
.\port-forward.ps1 all
```

### 📊 Durante o desenvolvimento:
```powershell
# Verificar status
.\k3d-manager.ps1 status

# Listar port-forwards
.\k3d-manager.ps1 list

# Iniciar Headlamp UI
.\k3d-manager.ps1 headlamp

# Parar port-forwards
.\k3d-manager.ps1 stop all
```

### 🔧 Troubleshooting:
```powershell
# Verificar Docker
.\k3d-manager.ps1 check

# Ver status completo
.\k3d-manager.ps1 status

# Recriar cluster do zero
.\k3d-manager.ps1 cleanup
.\k3d-manager.ps1 create
```

---

## 🎯 Workflow Típico

### 🆕 Primeira vez:
```powershell
# 1. Criar cluster completo
.\create-all-from-zero.ps1

# 2. Iniciar port-forwards em background
.\port-forward.ps1 all

# 3. Acessar serviços no browser
# - ArgoCD:  http://localhost:8090  (admin / Argo@123)
# - Grafana: http://localhost:3000  (rdpresser / rdpresser@123)
```

### 🔄 Após reiniciar o computador:
```powershell
# 1. Iniciar Docker Desktop (espere ficar pronto)

# 2. Iniciar o cluster k3d
.\start-cluster.ps1

# 3. Iniciar port-forwards
.\port-forward.ps1 all

# 4. Acessar serviços no browser
# - ArgoCD:  http://localhost:8090  (admin / Argo@123)
# - Grafana: http://localhost:3000  (rdpresser / rdpresser@123)
```

### 📊 Durante o desenvolvimento:
```powershell
# Verificar status dos port-forwards
.\list-port-forward.ps1

# Trabalhar no cluster sem terminal preso...

# Parar port-forwards quando terminar
.\stop-port-forward.ps1 all
```

---

## 🔐 Credenciais Padrão

### ArgoCD
- **URL**: http://localhost:8090 (HTTP)
- **Usuário**: `admin`
- **Senha**: `Argo@123`

### Grafana
- **URL**: http://localhost:3000
- **Admin**: `admin` / `Grafana@123`
- **Usuário**: `rdpresser` / `rdpresser@123` (Admin role)

### Headlamp
- **URL**: http://localhost:4466
- Usa kubeconfig local automaticamente

---

## ⚙️ Configuração do Cluster

O script `create-all-from-zero.ps1` cria um cluster com:

| Componente | Configuração |
|-----------|--------------|
| **Cluster Name** | `dev` |
| **Registry** | `localhost:5000` |
| **Servers** | 1 node (8GB RAM) |
| **Agents** | 2 nodes (8GB RAM cada) |
| **Portas** | 80:80, 443:443 |
| **Namespaces** | argocd, monitoring, keda, users |

---

## 🛠️ Troubleshooting

### ⚠️ Após reiniciar o computador o cluster não funciona
**Problema**: Port-forwards falham, kubectl não conecta, serviços inacessíveis.

**Causa**: Containers k3d param quando o Docker Desktop é reiniciado.

**Solução**:
```powershell
# 1. Inicie Docker Desktop e aguarde
# 2. Execute:
.\start-cluster.ps1

# 3. Depois faça port-forward:
.\port-forward.ps1 all
```

### ⚠️ Port-forward cria processos duplicados
**Problema**: Múltiplos processos kubectl na porta 8090/3000.

**Causa**: Shim do Chocolatey criando processos duplicados.

**Solução**: O script agora detecta e usa o executável real do kubectl automaticamente.

```powershell
# Se ainda ocorrer:
.\k3d-manager.ps1 stop all
.\k3d-manager.ps1 list
.\k3d-manager.ps1 port-forward all
```

### Registry já existe
O script detecta e reutiliza registry existente automaticamente.

### Cluster não deleta
```powershell
# Forçar deleção manual
k3d cluster delete dev

# Depois executar o script
.\create-all-from-zero.ps1
```

### Port-forward não inicia
```powershell
# Verificar se porta já está em uso
netstat -ano | findstr "8090"
netstat -ano | findstr "3000"

# Parar processos existentes
.\stop-port-forward.ps1 all

# Tentar novamente
.\port-forward.ps1 all
```

### Port-forward não conecta ou perde conexão
```powershell
# Verificar se pods estão rodando
kubectl get pods -n argocd
kubectl get pods -n monitoring

# Reiniciar port-forwards
.\stop-port-forward.ps1 all
.\port-forward.ps1 all
```

### Problemas de memória
Edite as variáveis no início do `create-all-from-zero.ps1`:
```powershell
$memoryPerNode = "8g"  # Ajuste conforme necessário
$agentMemory = "8g"    # Ajuste conforme necessário
```

---

## 📝 Notas Importantes

1. **K3D Manager**: Use `.\k3d-manager.ps1` como ponto de entrada principal
2. **Menu Interativo**: Execute sem parâmetros para menu visual
3. **Linha de Comando**: Todos os comandos suportam execução direta
4. **Idempotência**: Scripts podem ser executados múltiplas vezes com segurança
5. **Senhas**: Configuráveis no início do `create-all-from-zero.ps1`
6. **Persistência**: Grafana usa PersistentVolume de 5Gi
7. **Registry**: Compartilhado entre recriações do cluster
8. **Port-forwards**: Processos executam em background (WindowStyle Hidden)
9. **Headlamp**: Interface gráfica alternativa para gerenciar o cluster
10. **Status**: Use `.\k3d-manager.ps1 status` para visão geral rápida

---

## 🗑️ Scripts Removidos/Deprecated

| Script | Status | Motivo | Alternativa |
|--------|--------|--------|-------------|
| `restore-after-delete.ps1` | ❌ REMOVIDO | Idêntico ao create-all-from-zero.ps1 | Use `create-all-from-zero.ps1` |
| `PORT-FORWARD-README.md` | ❌ REMOVIDO | Documentação consolidada | Veja seções acima neste README |

---

## 💡 Dicas

### Usar o K3D Manager (Recomendado)

```powershell
# Criar alias permanente no PowerShell Profile
notepad $PROFILE

# Adicionar ao arquivo:
Set-Alias k3d "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\k3d-manager.ps1"

# Salvar e recarregar:
. $PROFILE

# Uso simplificado:
k3d                    # Menu interativo
k3d status            # Status do cluster
k3d create            # Criar cluster
k3d start             # Iniciar cluster
k3d port-forward all  # Port-forwards
k3d headlamp          # Iniciar Headlamp
```

### Criar alias no PowerShell Profile (Scripts Individuais)

```powershell
# Adicionar ao $PROFILE
Set-Alias k3d-reset "C:\...\create-all-from-zero.ps1"
Set-Alias pf "C:\...\port-forward.ps1"
Set-Alias pf-stop "C:\...\stop-port-forward.ps1"
Set-Alias pf-list "C:\...\list-port-forward.ps1"

# Uso
k3d-reset
pf all
pf-list
pf-stop all
```

### Ver logs de um serviço

```powershell
# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Acessar Prometheus

```powershell
kubectl port-forward -n monitoring svc/kube-prom-stack-prometheus 9090:9090
# Acesse: http://localhost:9090
```
