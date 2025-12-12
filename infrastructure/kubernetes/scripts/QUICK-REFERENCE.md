# ⚡ K3D Manager - Quick Reference

## 🎯 Main Command
```powershell
.\k3d-manager.ps1
```

## 📋 Commands
| Command | Description | Example |
|---------|-------------|---------|
| `create` | Create cluster from scratch | `.\k3d-manager.ps1 create` |
| `start` | Start cluster (after reboot) | `.\k3d-manager.ps1 start` |
| `cleanup` | Remove everything | `.\k3d-manager.ps1 cleanup` |
| `port-forward [svc]` | Start port-forwards | `.\k3d-manager.ps1 port-forward all` |
| `stop [svc]` | Stop port-forwards | `.\k3d-manager.ps1 stop argocd` |
| `list` | List active port-forwards | `.\k3d-manager.ps1 list` |
| `check` | Check Docker/network | `.\k3d-manager.ps1 check` |
| `headlamp` | Start Headlamp UI | `.\k3d-manager.ps1 headlamp` |
| `status` | Full status | `.\k3d-manager.ps1 status` |
| `help` | Help | `.\k3d-manager.ps1 --help` |
| `menu` | Interactive menu | `.\k3d-manager.ps1` |

## 🔗 Service URLs
| Service | URL | Credentials |
|---------|-----|-------------|
| Argo CD | http://localhost:8090 | admin / Argo@123 |
| Grafana | http://localhost:3000 | rdpresser / rdpresser@123 |
| Headlamp | http://localhost:4466 | kubeconfig |

## 🚀 Quick Workflows
```powershell
# First time
.\k3d-manager.ps1 create
.\k3d-manager.ps1 port-forward all

# After reboot
.\k3d-manager.ps1 start
.\k3d-manager.ps1 port-forward all

# Troubleshooting
.\k3d-manager.ps1 status
.\k3d-manager.ps1 check
.\k3d-manager.ps1 cleanup
.\k3d-manager.ps1 create
```

## 💡 Recommended Alias
```powershell
# Add to $PROFILE
Set-Alias k3d "C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\scripts\k3d-manager.ps1"

# Reload
. $PROFILE

# Use
k3d                   # Menu
k3d status            # Status
k3d create            # Create
k3d start             # Start
k3d port-forward all  # Port-forwards
```
