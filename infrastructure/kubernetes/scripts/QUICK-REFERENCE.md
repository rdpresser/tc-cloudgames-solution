# ⚡ K3D Manager - Referência Rápida

## 🎯 Comando Principal

```powershell
.\k3d-manager.ps1
```

## 📋 Todos os Comandos

| Comando | Descrição | Exemplo |
|---------|-----------|---------|
| `create` | Cria cluster do zero | `.\k3d-manager.ps1 create` |
| `start` | Inicia cluster (após reboot) | `.\k3d-manager.ps1 start` |
| `cleanup` | Remove tudo | `.\k3d-manager.ps1 cleanup` |
| `port-forward [svc]` | Inicia port-forwards | `.\k3d-manager.ps1 port-forward all` |
| `stop [svc]` | Para port-forwards | `.\k3d-manager.ps1 stop argocd` |
| `list` | Lista port-forwards | `.\k3d-manager.ps1 list` |
| `check` | Verifica Docker/rede | `.\k3d-manager.ps1 check` |
| `headlamp` | Inicia Headlamp UI | `.\k3d-manager.ps1 headlamp` |
| `status` | Status completo | `.\k3d-manager.ps1 status` |
| `help` | Ajuda | `.\k3d-manager.ps1 --help` |
| `menu` | Menu interativo | `.\k3d-manager.ps1` |

## 🔗 URLs dos Serviços

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| ArgoCD | http://localhost:8080 | admin / Argo@123 |
| Grafana | http://localhost:3000 | rdpresser / rdpresser@123 |
| Headlamp | http://localhost:4466 | - |

## 🚀 Workflows Rápidos

### Primeira Vez
```powershell
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all
```

### Após Reboot
```powershell
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all
```

### Troubleshooting
```powershell
.\k3d-manager.ps1 status
.\k3d-manager.ps1 check
.\k3d-manager.ps1 cleanup
.\k3d-manager.ps1 create
```

## 💡 Alias Recomendado

```powershell
# Adicionar ao $PROFILE
Set-Alias k3d "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\k3d-manager.ps1"

# Recarregar
. $PROFILE

# Uso
k3d                # Menu
k3d status         # Status
k3d create         # Criar
k3d start          # Iniciar
k3d port-forward all  # Port-forwards
```
