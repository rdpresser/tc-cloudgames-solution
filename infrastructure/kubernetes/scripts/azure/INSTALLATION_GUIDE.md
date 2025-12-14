# 🚀 Guia de Instalação - CloudGames AKS

## 📋 Ordem Recomendada de Instalação

### 1️⃣ **ArgoCD** (GitOps Controller)
```powershell
.\aks-manager.ps1 install-argocd
```

**O que faz:**
- Instala ArgoCD via Helm
- Configura LoadBalancer com IP público
- Define senha admin: `Argo@AKS123!`

**Por que primeiro:**
- Gerencia deployments via Git (declarativo)
- Aplica manifestos Kubernetes automaticamente
- Sincroniza estado desejado vs atual

**Idempotente:** ✅ Se já existe, pergunta se quer reinstalar

---

### 2️⃣ **External Secrets Operator (ESO)** (Gerenciador de Secrets)
```powershell
.\aks-manager.ps1 install-eso
```

**O que faz:**
- Instala ESO via Helm
- Configura CRDs (ExternalSecret, SecretStore)
- Prepara integração com Azure Key Vault

**Por que ESO:**
- ❌ **Sem ESO:** Secrets hardcoded ou via Terraform (estático)
- ✅ **Com ESO:** Sincroniza automaticamente do Key Vault
- Managed Identity/RBAC autentica ESO no Key Vault
- Atualização dinâmica de secrets (sem redeploy)

**Exemplo de uso:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: azure-keyvault
  target:
    name: db-secret
  data:
  - secretKey: password
    remoteRef:
      key: database-password  # Nome no Key Vault
```

**Idempotente:** ✅ Se já existe, pergunta se quer reinstalar

---

### 3️⃣ **NGINX Ingress Controller** (Roteamento de Tráfego)
```powershell
.\aks-manager.ps1 install-nginx
```

**O que faz:**
- Instala NGINX Ingress via Helm
- Cria LoadBalancer com IP público único
- Gerencia roteamento HTTP/HTTPS

**Por que NGINX:**
- **Sem NGINX:** Cada serviço precisa de LoadBalancer ($30-50/mês cada)
- **Com NGINX:** 1 LoadBalancer para TODOS os serviços ($30-50/mês total)
- Roteamento por domínio/path: `api.cloudgames.com/users`, `/games`, `/payments`
- TLS/SSL centralizado (Let's Encrypt)
- Rate limiting, CORS, headers customizados

**Economia de custo:**
```
Sem NGINX:
- user-api LoadBalancer: $40/mês
- games-api LoadBalancer: $40/mês
- payments-api LoadBalancer: $40/mês
Total: $120/mês

Com NGINX:
- NGINX LoadBalancer: $40/mês
Total: $40/mês
Economia: $80/mês (67%)
```

**Idempotente:** ✅ Se já existe, pergunta se quer reinstalar

---

### 4️⃣ **Grafana Agent** (Observabilidade)
```powershell
.\aks-manager.ps1 install-grafana-agent
```

**O que faz:**
- Instala Grafana Agent via Helm
- Coleta métricas, logs, traces
- Envia para Grafana Cloud

**Por que Grafana Agent:**
- Monitora performance de APIs
- Alerta em caso de erros/downtime
- Análise de logs centralizada
- Troubleshooting rápido

**Idempotente:** ✅ Se já existe, pergunta se quer reinstalar

---

### 5️⃣ **Build & Push Images** (Docker para ACR)
```powershell
.\aks-manager.ps1 build-push
# Escolha: all, user, games, ou payments
```

**O que faz:**
- Compila Docker images das APIs (.NET)
- Faz push para Azure Container Registry (ACR)
- Tag configurável (padrão: `dev`)

**APIs disponíveis:**
- `user-api`: Autenticação, usuários
- `games-api`: Catálogo de jogos
- `payments-api`: Processamento de pagamentos

**Exemplo ACR:**
```
tccloudgamesdevcr8nacr.azurecr.io/user-api:dev
tccloudgamesdevcr8nacr.azurecr.io/games-api:dev
tccloudgamesdevcr8nacr.azurecr.io/payments-api:dev
```

---

### 6️⃣ **Bootstrap ArgoCD Applications** (Deploy via GitOps)
```powershell
.\aks-manager.ps1 bootstrap dev
```

**O que faz:**
- Aplica ArgoCD Application manifests
- ArgoCD sincroniza repositório Git
- Deploy automático de user-api, games-api, payments-api

**Resultado:**
- Pods rodando no namespace `cloudgames`
- Services expostos via NGINX Ingress
- Secrets sincronizados do Key Vault via ESO

---

## 🎯 Script Completo (Ordem de Instalação)

```powershell
# 1. Conectar ao cluster
.\aks-manager.ps1 connect

# 2. Verificar status
.\aks-manager.ps1 status

# 3. Instalar componentes (ORDEM IMPORTANTE)
.\aks-manager.ps1 install-argocd          # GitOps
.\aks-manager.ps1 install-eso             # Secrets do Key Vault
.\aks-manager.ps1 install-nginx           # Ingress/Roteamento
.\aks-manager.ps1 install-grafana-agent   # Observabilidade

# Ou instalar tudo de uma vez:
.\aks-manager.ps1 install-all

# 4. Build e push das images
.\aks-manager.ps1 build-push

# 5. Deploy via ArgoCD
.\aks-manager.ps1 bootstrap dev

# 6. Verificar ArgoCD URL
.\aks-manager.ps1 get-argocd-url
```

---

## ✅ Características dos Scripts (Idempotência)

Todos os scripts agora são **idempotentes**:

1. **Detecta se já existe instalação**
2. **Pergunta se quer reinstalar:** `Do you want to REINSTALL? (y/N)`
3. **Comportamento:**
   - `y` ou `Y`: Remove completamente e reinstala
   - Qualquer outra tecla: Sai sem fazer nada
   - Enter (vazio): Sai sem fazer nada

**Exemplo:**
```powershell
.\aks-manager.ps1 install-argocd

# Se já existe:
⚠️  ArgoCD is already installed in namespace 'argocd'

Do you want to REINSTALL ArgoCD? This will DELETE and recreate it. (y/N)
> n

ℹ️  Installation cancelled. Existing ArgoCD installation preserved.
```

---

## 🔑 Secrets Management Flow

```
Key Vault (Azure)
    ↓
ESO + Managed Identity (RBAC)
    ↓
Kubernetes Secrets (auto-sync)
    ↓
Pods (secretRef)
```

**Sem manual intervention!**

---

## 🌐 Ingress Routing Example

```yaml
# Após NGINX instalado
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cloudgames-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: api.cloudgames.com
    http:
      paths:
      - path: /users
        pathType: Prefix
        backend:
          service:
            name: user-api
            port:
              number: 80
      - path: /games
        pathType: Prefix
        backend:
          service:
            name: games-api
            port:
              number: 80
      - path: /payments
        pathType: Prefix
        backend:
          service:
            name: payments-api
            port:
              number: 80
```

**Resultado:**
- `http://api.cloudgames.com/users` → user-api
- `http://api.cloudgames.com/games` → games-api
- `http://api.cloudgames.com/payments` → payments-api

**Um único IP público!**

---

## 📊 Menu Atualizado

```
[1] Connect to AKS cluster
[2] Show cluster status
[3] Install ArgoCD
[4] Install Grafana Agent
[5] Install External Secrets Operator
[6] Install NGINX Ingress
[7] Install ALL components
[8] Get ArgoCD URL & credentials
[9] Bootstrap ArgoCD apps
[10] Build & Push images to ACR
[11] View logs
[0] Exit
```

**Removido:** Item de reset separado (agora integrado no install)

---

## 🛠️ Troubleshooting

### Ver logs de componente:
```powershell
.\aks-manager.ps1 logs argocd
.\aks-manager.ps1 logs eso
.\aks-manager.ps1 logs nginx
.\aks-manager.ps1 logs grafana-agent
```

### Reinstalar componente com problema:
```powershell
# Script detecta instalação existente e pergunta se quer reinstalar
.\aks-manager.ps1 install-argocd
> y  # Confirma reinstalação
```

### Build de API específica:
```powershell
.\aks-manager.ps1 build-push user    # Só user-api
.\aks-manager.ps1 build-push games   # Só games-api
```

---

## 🎯 Próximos Passos (CI/CD)

Após validar manualmente, automatizar com GitHub Actions:

```yaml
name: Build and Deploy
on:
  push:
    branches: [main, develop]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/docker-login@v1
        with:
          login-server: tccloudgamesdevcr8nacr.azurecr.io
      
      - name: Build and push
        run: |
          docker build -t $ACR_REGISTRY/user-api:${{ github.sha }} .
          docker push $ACR_REGISTRY/user-api:${{ github.sha }}
      
      - name: Update ArgoCD manifest
        run: |
          # Update image tag in Git repository
          # ArgoCD auto-syncs and deploys
```

---

## 📝 Checklist de Instalação

- [ ] Conectar ao AKS: `.\aks-manager.ps1 connect`
- [ ] Instalar ArgoCD: `.\aks-manager.ps1 install-argocd`
- [ ] Instalar ESO: `.\aks-manager.ps1 install-eso`
- [ ] Instalar NGINX: `.\aks-manager.ps1 install-nginx`
- [ ] Instalar Grafana: `.\aks-manager.ps1 install-grafana-agent`
- [ ] Build images: `.\aks-manager.ps1 build-push`
- [ ] Bootstrap apps: `.\aks-manager.ps1 bootstrap dev`
- [ ] Verificar status: `.\aks-manager.ps1 status`
- [ ] Acessar ArgoCD: `.\aks-manager.ps1 get-argocd-url`

✅ **Pronto para produção!**
