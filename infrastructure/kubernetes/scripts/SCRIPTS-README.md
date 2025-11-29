# 🚀 Scripts de Gerenciamento do Cluster K3D

> **💡 NOVO!** Use o **K3D Manager** para facilitar o gerenciamento do cluster local.  
> Menu interativo + linha de comando em um único lugar!

## ⚡ Quick Start

```powershell
# 1️⃣ Menu interativo (recomendado para iniciantes)
.\k3d-manager.ps1

# 2️⃣ Ver ajuda completa
.\k3d-manager.ps1 --help

# 3️⃣ Comandos diretos (para usuários avançados)
.\k3d-manager.ps1 status              # Status do cluster
.\k3d-manager.ps1 create              # Criar cluster do zero
.\k3d-manager.ps1 start               # Iniciar após reboot
.\k3d-manager.ps1 port-forward all    # Port-forwards
.\k3d-manager.ps1 headlamp            # UI gráfica
```

## 🎯 Fluxo Recomendado

### 🆕 Primeira vez configurando:
```powershell
.\k3d-manager.ps1 create              # Cria cluster completo
.\k3d-manager.ps1 port-forward all    # Ativa port-forwards
.\k3d-manager.ps1 headlamp            # (Opcional) UI gráfica
```

### 🔄 Após reiniciar o computador:
```powershell
.\k3d-manager.ps1 start               # Inicia cluster
.\k3d-manager.ps1 port-forward all    # Ativa port-forwards
```

### 📊 Verificar status:
```powershell
.\k3d-manager.ps1 status              # Status completo
.\k3d-manager.ps1 list                # Port-forwards ativos
```

---

## 🎯 Quick Start

### Gerenciador Principal (Recomendado)
```powershell
# Menu interativo
.\k3d-manager.ps1

# Ajuda e lista de comandos
.\k3d-manager.ps1 --help

# Execução direta de comandos
.\k3d-manager.ps1 create
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all
.\k3d-manager.ps1 status
```

---

## 📦 Scripts Disponíveis

### 0️⃣ **`k3d-manager.ps1`** 🎯 (PRINCIPAL - Novo!)

**Função**: Orquestrador central que gerencia todos os scripts.

**O que faz:**
- ✅ Menu interativo para fácil navegação
- ✅ Suporte a linha de comando
- ✅ Status consolidado do cluster
- ✅ Executa qualquer script de forma centralizada
- ✅ Ajuda integrada com --help

**Uso:**
```powershell
# Menu interativo (padrão)
.\k3d-manager.ps1

# Linha de comando
.\k3d-manager.ps1 create              # Criar cluster
.\k3d-manager.ps1 start               # Iniciar cluster
.\k3d-manager.ps1 port-forward all    # Port-forwards
.\k3d-manager.ps1 stop argocd         # Parar port-forward
.\k3d-manager.ps1 list                # Listar port-forwards
.\k3d-manager.ps1 check               # Verificar Docker
.\k3d-manager.ps1 status              # Status do cluster
.\k3d-manager.ps1 headlamp            # Iniciar Headlamp
.\k3d-manager.ps1 cleanup             # Limpar tudo
```

**Comandos disponíveis:**
- `create` - Cria/recria cluster completo
- `start` - Inicia cluster após reboot
- `cleanup` - Remove cluster e recursos
- `port-forward [svc]` - Inicia port-forwards
- `stop [svc]` - Para port-forwards
- `list` - Lista port-forwards ativos
- `check` - Verifica Docker/rede
- `headlamp` - Inicia Headlamp UI
- `status` - Mostra status completo
- `help` - Mostra ajuda
- `menu` - Abre menu interativo

---

### 1️⃣ **`create-all-from-zero.ps1`** ⭐ (Principal)

**Função**: Cria/recria o ambiente completo do cluster k3d com todos os componentes.

**O que faz:**
- ✅ Verifica dependências (kubectl, helm, k3d, docker)
- ✅ Cria registry local (se não existir)
- ✅ Deleta cluster existente (se houver)
- ✅ Cria novo cluster k3d (1 server + 2 agents, 8GB cada)
- ✅ Instala ArgoCD
- ✅ Instala KEDA
- ✅ Instala Prometheus + Grafana (kube-prometheus-stack)
- ✅ Configura senha do ArgoCD para `Argo@123`
- ✅ Cria usuário Grafana `rdpresser` / `rdpresser@123`

**Uso:**
```powershell
.\create-all-from-zero.ps1
```

**Quando usar:**
- ✅ Primeira vez configurando o ambiente
- ✅ Resetar tudo para estado limpo
- ✅ Após problemas no cluster
- ✅ Mudança de configuração de recursos

---

### 1.1️⃣ **`start-cluster.ps1`** 🚀 (Após Reboot)

**Função**: Inicia o cluster k3d após reiniciar o computador.

**O que faz:**
- ✅ Verifica se Docker está rodando
- ✅ Lista clusters k3d existentes
- ✅ Inicia containers do cluster "dev"
- ✅ Configura contexto kubectl
- ✅ Aguarda pods principais ficarem prontos
- ✅ Mostra instruções de próximos passos

**Uso:**
```powershell
.\start-cluster.ps1
```

**Quando usar:**
- ✅ **SEMPRE após reiniciar o computador**
- ✅ Quando Docker Desktop foi reiniciado
- ✅ Quando cluster está parado mas não deletado
- ⚠️ **EXECUTAR ANTES de fazer port-forward**

**Fluxo após reboot:**
```powershell
# 1. Inicie o Docker Desktop e aguarde estar pronto
# 2. Execute:
.\start-cluster.ps1

# 3. Depois execute:
.\port-forward.ps1 all
```

---

### 2️⃣ **`port-forward.ps1`** 🔌

**Função**: Inicia port-forwards em modo background (detached).

**O que faz:**
- Inicia processos kubectl port-forward em background
- Não bloqueia o terminal (modo detached, similar ao `docker run -d`)
- Verifica se port-forward já está ativo antes de iniciar
- Suporta iniciar ArgoCD, Grafana ou ambos

**Uso:**
```powershell
# Ambos os serviços (padrão)
.\port-forward.ps1
.\port-forward.ps1 all

# Apenas ArgoCD
.\port-forward.ps1 argocd

# Apenas Grafana
.\port-forward.ps1 grafana
```

**Portas:**
- 🔐 **ArgoCD**: `http://localhost:8080` (HTTP insecure)
- 📊 **Grafana**: `http://localhost:3000` → kube-prom-stack-grafana:80

**Características:**
- ✅ Modo detached (WindowStyle Hidden)
- ✅ Verificação de duplicatas (detecta port-forwards já ativos)
- ✅ Validação de portas (verifica disponibilidade)
- ✅ Feedback visual colorido
- ✅ Processos persistem após fechar terminal

---

### 3️⃣ **`stop-port-forward.ps1`** 🛑

**Função**: Para port-forwards ativos.

**O que faz:**
- Identifica processos kubectl port-forward em execução
- Encerra processos específicos ou todos
- Busca por PID e linha de comando

**Uso:**
```powershell
# Parar todos os port-forwards
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
   Porta:   http://localhost:8080
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
- Checa portas necessárias (80, 443, 8080, 3000)

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
# - ArgoCD:  http://localhost:8080  (admin / Argo@123)
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
# - ArgoCD:  http://localhost:8080  (admin / Argo@123)
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
- **URL**: http://localhost:8080 (HTTP)
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
| **Registry** | `k3d-registry.local:5000` |
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
**Problema**: Múltiplos processos kubectl na porta 8080/3000.

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
netstat -ano | findstr "8080"
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
