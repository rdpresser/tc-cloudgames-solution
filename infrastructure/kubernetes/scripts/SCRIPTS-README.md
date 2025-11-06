# 🚀 Scripts de Gerenciamento do Cluster K3D

## 📦 Scripts Disponíveis

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
- 🔐 **ArgoCD**: `http://localhost:8080` → argocd-server:443
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

## 🎯 Workflow Típico

```powershell
# 1. Criar/Recriar cluster completo
.\create-all-from-zero.ps1

# 2. Iniciar port-forwards em background
.\port-forward.ps1 all

# 3. Acessar serviços no browser
# - ArgoCD:  http://localhost:8080  (admin / Argo@123)
# - Grafana: http://localhost:3000  (rdpresser / rdpresser@123)

# 4. Verificar status dos port-forwards
.\list-port-forward.ps1

# 5. Trabalhar no cluster sem terminal preso...

# 6. Parar port-forwards quando terminar
.\stop-port-forward.ps1 all
```

---

## 🔐 Credenciais Padrão

### ArgoCD
- **URL**: http://localhost:8080
- **Usuário**: `admin`
- **Senha**: `Argo@123`

### Grafana
- **URL**: http://localhost:3000
- **Admin**: `admin` / `Grafana@123`
- **Usuário**: `rdpresser` / `rdpresser@123` (Admin role)

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

1. **Idempotência**: `create-all-from-zero.ps1` pode ser executado múltiplas vezes
2. **Senhas**: Todas as senhas são configuráveis no início do script
3. **Persistência**: Grafana usa PersistentVolume de 5Gi
4. **Registry**: Compartilhado entre recriações do cluster
5. **Port-forwards em background**: Scripts executam processos em WindowStyle Hidden
6. **Port-forwards persistem**: Sobrevivem ao fechamento da janela PowerShell

---

## 🗑️ Scripts Removidos/Deprecated

| Script | Status | Motivo | Alternativa |
|--------|--------|--------|-------------|
| `restore-after-delete.ps1` | ❌ REMOVIDO | Idêntico ao create-all-from-zero.ps1 | Use `create-all-from-zero.ps1` |
| `PORT-FORWARD-README.md` | ❌ REMOVIDO | Documentação consolidada | Veja seções acima neste README |

---

## 💡 Dicas

### Criar alias no PowerShell Profile

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
