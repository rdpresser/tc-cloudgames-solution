# 🚀 Kubernetes Local (K3D)

Ambiente Kubernetes local usando K3D para desenvolvimento e testes.

## ⚡ Quick Start

```powershell
# Navegue até a pasta de scripts
cd infrastructure\kubernetes\scripts

# Execute o gerenciador principal
.\k3d-manager.ps1
```

## 📋 Estrutura

```
infrastructure/kubernetes/
├── manifests/           # Manifestos Kubernetes
│   └── application.yaml # ArgoCD Application principal
├── scripts/            # Scripts de gerenciamento
│   ├── k3d-manager.ps1            # 🎯 GERENCIADOR PRINCIPAL
│   ├── create-all-from-zero.ps1   # Criar cluster
│   ├── start-cluster.ps1          # Iniciar cluster
│   ├── port-forward.ps1           # Port-forwards
│   ├── stop-port-forward.ps1      # Parar port-forwards
│   ├── list-port-forward.ps1      # Listar port-forwards
│   ├── cleanup-all.ps1            # Limpar recursos
│   ├── check-docker-network.ps1   # Diagnosticar rede
│   ├── start-headlamp-docker.ps1  # UI Headlamp
│   ├── SCRIPTS-README.md          # 📖 Documentação completa
│   └── TROUBLESHOOTING-NETWORK.md # 🔧 Troubleshooting
```

## 🎯 Comandos Principais

### Via K3D Manager (Recomendado)

```powershell
.\k3d-manager.ps1              # Menu interativo
.\k3d-manager.ps1 --help       # Ver todos os comandos
.\k3d-manager.ps1 status       # Status do cluster
.\k3d-manager.ps1 create       # Criar cluster
.\k3d-manager.ps1 start        # Iniciar cluster
.\k3d-manager.ps1 port-forward all  # Port-forwards
```

### Scripts Individuais

```powershell
.\create-all-from-zero.ps1     # Criar cluster completo
.\start-cluster.ps1            # Iniciar após reboot
.\port-forward.ps1 all         # Ativar port-forwards
.\list-port-forward.ps1        # Listar ativos
.\stop-port-forward.ps1 all    # Parar port-forwards
.\cleanup-all.ps1              # Limpar tudo
```

## 🔗 Serviços Disponíveis

Após executar `.\k3d-manager.ps1 port-forward all`:

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| **ArgoCD** | http://localhost:8080 | `admin` / `Argo@123` |
| **Grafana** | http://localhost:3000 | `rdpresser` / `rdpresser@123` |
| **Headlamp** | http://localhost:4466 | Automático (kubeconfig) |
| **Prometheus** | Port-forward manual | - |

## 📚 Documentação

- **[SCRIPTS-README.md](scripts/SCRIPTS-README.md)** - Documentação completa de todos os scripts
- **[TROUBLESHOOTING-NETWORK.md](scripts/TROUBLESHOOTING-NETWORK.md)** - Resolução de problemas de rede

## 🔧 Configuração do Cluster

| Componente | Configuração |
|-----------|--------------|
| **Nome** | `dev` |
| **Registry** | `k3d-registry.local:5000` |
| **Servers** | 1 node (8GB RAM) |
| **Agents** | 2 nodes (8GB RAM cada) |
| **Portas** | 80:80, 443:443 |
| **Namespaces** | argocd, monitoring, keda, users |

### Componentes Instalados

- ✅ **ArgoCD** - GitOps / CD
- ✅ **KEDA** - Event-driven autoscaling
- ✅ **Prometheus** - Métricas
- ✅ **Grafana** - Visualização
- ✅ **Headlamp** (opcional) - UI Kubernetes

## 🎯 Workflows Comuns

### Primeira vez configurando

```powershell
cd infrastructure\kubernetes\scripts
.\k3d-manager.ps1 create              # Cria cluster
.\k3d-manager.ps1 port-forward all    # Ativa serviços
# Acesse: http://localhost:8090 (ArgoCD)
```

### Após reiniciar o computador

```powershell
cd infrastructure\kubernetes\scripts
.\k3d-manager.ps1 start               # Inicia cluster
.\k3d-manager.ps1 port-forward all    # Ativa serviços
```

### Verificar status

```powershell
.\k3d-manager.ps1 status              # Status completo
.\k3d-manager.ps1 list                # Port-forwards ativos
kubectl get pods -A                   # Pods em todos namespaces
```

### Limpar e recriar

```powershell
.\k3d-manager.ps1 cleanup             # Remove tudo
.\k3d-manager.ps1 create              # Recria cluster
```

## 🛠️ Troubleshooting Rápido

### Cluster não inicia após reboot

```powershell
.\k3d-manager.ps1 start
```

### Port-forward não conecta

```powershell
.\k3d-manager.ps1 stop all
.\k3d-manager.ps1 port-forward all
```

### Problemas de rede/Docker

```powershell
.\k3d-manager.ps1 check               # Diagnóstico completo
```

### Recomeçar do zero

```powershell
.\k3d-manager.ps1 cleanup
wsl --shutdown                        # Se usar WSL2
# Reiniciar Docker Desktop
.\k3d-manager.ps1 create
```

## 💡 Dicas

1. **Use o K3D Manager**: Centralize operações em um único comando
2. **Alias no PowerShell**: Crie um alias `k3d` para `.\k3d-manager.ps1`
3. **Menu Interativo**: Execute sem parâmetros para navegação visual
4. **Status Rápido**: Use `status` para ver tudo de uma vez
5. **Headlamp UI**: Interface gráfica alternativa ao kubectl

## 🔗 Links Úteis

- [K3D Documentation](https://k3d.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Grafana](https://grafana.com/docs/)
- [KEDA](https://keda.sh/)
- [Headlamp](https://headlamp.dev/)
