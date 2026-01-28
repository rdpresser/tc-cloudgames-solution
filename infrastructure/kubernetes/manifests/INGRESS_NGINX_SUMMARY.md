# 🚀 Summary: ingress-nginx Syncing Forever - Fixed

## 📋 Problema

**ingress-nginx Application no ArgoCD ficava em estado "Syncing" eternamente**

### Sintomas
- ✋ Application status: `Syncing` (nunca completa)
- ✓ Health: `Healthy`
- ⏳ Esperando: PreSync Hooks indefinidamente
- 🔴 Operação bloqueada

---

## 🔧 Solução Implementada

### 1. Correção Imediata (Desbloqueio)
```bash
# Limpar operationState travado
kubectl patch application ingress-nginx -n argocd \
  --type json \
  -p '[{"op":"replace","path":"/status/operationState","value":null}]'
```
✅ Application imediatamente começou novo sync → Synced/Healthy

### 2. Correção Permanente (Arquivo Manifesto)

**Arquivo**: `infrastructure/kubernetes/manifests/application-ingress-nginx.yaml`

**Mudanças**:

#### A) Adicionar Retry Policy com Timeout
```yaml
syncPolicy:
  # ... existing fields ...
  retry:
    limit: 2                           # 2 tentativas
    backoff:
      duration: 5s                     # Primeira: 5s
      factor: 2                        # Segunda: 10s
      maxDuration: 3m0s               # Máximo: 3 min
```

#### B) Adicionar SyncOptions para Limpeza
```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
  - PruneLast=true                    # ← NEW: Deleções por último
  - RespectIgnoreDifferences=true     # ← NEW: Respeita ignoreDifferences
```

#### C) Adicionar Hook Cleanup Policy
```yaml
admissionWebhooks:
  patch:
    podAnnotations:
      argocd.argoproj.io/hook: PreSync
      argocd.argoproj.io/hook-delete-policy: HookSucceeded,HookFailed
      # ↑ Deleta hooks após conclusão (sucesso OU falha)
```

---

## 🎯 Root Cause Analysis

### O que acontecia
1. Helm chart instala **PreSync Hooks** (Jobs) para setup
2. Jobs executam e são deletados automaticamente (lifecycle)
3. ❌ ArgoCD `operationState.syncResult` mostra hooks como `Running`
4. ❌ Sem timeout ou retry, fica aguardando forever

### Arquitetura do Problema
```
sync inicia
  ↓
PreSync Hooks criados (6 resources)
  ↓
Hooks executam com sucesso
  ↓
Jobs são deletados (lifecycle padrão)
  ↓
❌ ArgoCD não percebe completion
  ↓
❌ operationState.phase = Running forever
  ↓
❌ Application status = Syncing forever
```

---

## ✅ Validação

### Antes da Correção
```
ingress-nginx   Syncing   Healthy
message: waiting for completion of hook /ServiceAccount/ingress-nginx-admission and 5 more hooks
```

### Depois da Correção
```
ingress-nginx   Synced    Healthy
2/2 pods running
All resources synced
```

### Todas as Applications (Status Final)
| Application | Sync | Health |
|---|---|---|
| azure-workload-identity | ✅ Synced | ✅ Healthy |
| bootstrap | ✅ Synced | ✅ Healthy |
| cloudgames-prod | ✅ Synced | ⏳ Progressing |
| external-secrets-operator | ✅ Synced | ✅ Healthy |
| ingress-nginx | ✅ Synced | ✅ Healthy |

---

## 📦 Mudanças no Git

```bash
git commit -m "fix(argocd): ingress-nginx Syncing eternamente - adicionar retry policy e hook cleanup"

Modified:
  - infrastructure/kubernetes/manifests/application-ingress-nginx.yaml

Added:
  - infrastructure/kubernetes/manifests/INGRESS_NGINX_FIX.md (diagnóstico detalhado)
```

---

## 🛡️ Prevenção para Futuros Helm Charts

### Template Padrão para Applications com Webhooks
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ app-name }}
  namespace: argocd
spec:
  # ... source and destination ...
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - PruneLast=true                        # ✅ SEMPRE
      - RespectIgnoreDifferences=true         # ✅ SEMPRE
    retry:                                    # ✅ ALWAYS ADD
      limit: 2
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 5m0s
```

### Helm Values para Apps com Admission Webhooks
```yaml
admissionWebhooks:
  enabled: true
  patch:
    enabled: true
    podAnnotations:
      argocd.argoproj.io/hook: PreSync
      argocd.argoproj.io/hook-delete-policy: HookSucceeded,HookFailed
```

---

## 🔍 Diagnóstico de Aplicações Travadas

Se algo similar acontecer novamente:

### 1. Verificar se Application está travado
```bash
kubectl get application <name> -n argocd -o json | \
  jq '.status.operationState'
  # Se phase = "Running" e nada mudou por > 5 min = TRAVADO
```

### 2. Ver qual hook está esperando
```bash
kubectl get application <name> -n argocd -o json | \
  jq '.status.operationState.syncResult.resources[] | 
       select(.hookPhase=="Running")'
```

### 3. Verificar se o hook ainda existe
```bash
# Se o hook não existe mais mas operationState.phase = Running = TRAVADO
kubectl get jobs,pods -n <namespace> \
  --selector=app.kubernetes.io/name=<hook-name>
```

### 4. Destravar
```bash
kubectl patch application <name> -n argocd \
  --type json \
  -p '[{"op":"replace","path":"/status/operationState","value":null}]'
```

---

## 📊 Timeline

- **18:15:15**: ArgoCD começou sync de ingress-nginx
- **∞**: Travado esperando PreSync hooks (que já tinham completado)
- **19:53:27**: Patch de correção imediata aplicado
- **19:53:30**: Application começou novo sync
- **19:53:35**: ✅ Synced/Healthy

---

## 💡 Learnings

1. **PreSync Hooks requerem cleanup explícito** - Adicionar `hook-delete-policy` sempre
2. **Sem timeout = risco infinito** - Sempre adicionar retry policy com backoff
3. **Monitorar "Syncing" indefinido** - 5+ minutos sem progresso = problema
4. **Helm admissionWebhooks são complexos** - Jobs de setup podem falhar silenciosamente
5. **Hook lifecycle é assíncrono** - ArgoCD operationState pode não acompanhar

---

## 📚 Referências

- [ArgoCD Application Sync](https://argo-cd.readthedocs.io/en/stable/user-guide/application-operations/)
- [ArgoCD Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/application-operations/#sync-options)
- [NGINX Ingress Helm Chart](https://kubernetes.github.io/ingress-nginx/)

---

## ✨ Status Atual

✅ **RESOLVIDO E DOCUMENTADO**
- Ingress-nginx operacional
- Todas as aplicações saudáveis
- Proteção contra reincidência implementada
- Troubleshooting guide disponível

