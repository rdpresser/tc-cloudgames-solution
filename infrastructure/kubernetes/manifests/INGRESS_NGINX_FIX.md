# 🔧 Correção: ingress-nginx Syncing Eternamente no ArgoCD

**Data**: 28 de Janeiro de 2026  
**Problema**: Application `ingress-nginx` ficava eternamente em estado "Syncing"  
**Causa**: PreSync Hooks travados aguardando completion indefinidamente  
**Status**: ✅ **RESOLVIDO**

---

## 🔍 Diagnóstico

### Sintomas

- Application status: **Syncing** (nunca completa)
- Health: ✅ Healthy
- Message: `waiting for completion of hook /ServiceAccount/ingress-nginx-admission and 5 more hooks`

### Root Cause

Helm chart do `ingress-nginx` instala **PreSync Hooks** (Jobs) para gerar certificados e atualizar webhooks. Esses hooks foram criados no `operationState` de ArgoCD, mas:

1. ❌ Os Jobs em si já tinham sido executados/deletados (não existiam mais)
2. ❌ ArgoCD continuava esperando pela completion
3. ❌ Estado travado indefinidamente sem timeout

### Fluxo Problemático

```
ArgoCD inicia sync
  ↓
Helm renderiza chart (inclui PreSync hooks)
  ↓
PreSync Hooks criados e executados:
  - ServiceAccount/ingress-nginx-admission ✅
  - ClusterRole/ingress-nginx-admission ✅
  - ClusterRoleBinding/ingress-nginx-admission ✅
  - Role/ingress-nginx-admission ✅
  - RoleBinding/ingress-nginx-admission ✅
  - Job/ingress-nginx-admission-create ✅
  ↓
Jobs completam e são deletados (lifecycle padrão)
  ↓
❌ ArgoCD operationState.syncResult ainda mostra hookPhase: Running
  ↓
❌ Status fica "Syncing" para sempre (nunca reconhece completion)
```

---

## ✅ Soluções Aplicadas

### 1. **Limpeza Imediata** (Resolução Rápida)

```powershell
# Limpar operationState travado
kubectl patch application ingress-nginx -n argocd \
  --type json \
  -p '[{"op":"replace","path":"/status/operationState","value":null}]'
```

**Resultado**: Application imediatamente começou novo sync e ficou `Synced/Healthy`

### 2. **Correção Permanente** (Manifesto)

Arquivo: `infrastructure/kubernetes/manifests/application-ingress-nginx.yaml`

#### Problema Identificado

```yaml
# ❌ ANTES: Sem retry policy, sem timeout, hooks sem policy de limpeza
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

#### Solução

```yaml
# ✅ DEPOIS: Com retry policy, timeout, e hook cleanup
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - PruneLast=true # Deleções acontecem por último
    - RespectIgnoreDifferences=true # Respeita ignoreDifferences
  retry:
    limit: 2 # 2 tentativas de retry
    backoff:
      duration: 5s
      factor: 2 # Backoff exponencial: 5s, 10s
      maxDuration: 3m0s # Máx 3 minutos entre tentativas
```

#### Helm Values - Hook Cleanup Policy

```yaml
admissionWebhooks:
  enabled: true
  patch:
    enabled: true
    # Adicionar anotações para limpeza automática de hooks após conclusão
    podAnnotations:
      argocd.argoproj.io/hook: PreSync
      argocd.argoproj.io/hook-delete-policy: HookSucceeded,HookFailed
```

**O que isso faz**:

- `HookSucceeded`: Deleta hook se completar com sucesso
- `HookFailed`: Deleta hook se falhar
- Impede que estado "ghost" permaneça em operationState

---

## 🎯 Mudanças no Manifesto

### Arquivo: `application-ingress-nginx.yaml`

**Antes**:

```yaml
admissionWebhooks:
  enabled: true
  patch:
    enabled: true
  # ❌ Sem policy de cleanup dos hooks
```

**Depois**:

```yaml
admissionWebhooks:
  enabled: true
  patch:
    enabled: true
    # ✅ Cleanup automático após conclusão
    podAnnotations:
      argocd.argoproj.io/hook: PreSync
      argocd.argoproj.io/hook-delete-policy: HookSucceeded,HookFailed
```

**Antes**:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
  # ❌ Sem retry policy ou timeout
```

**Depois**:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - PruneLast=true
    - RespectIgnoreDifferences=true
  retry:
    limit: 2
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m0s
  # ✅ Com retry policy e timeout
```

---

## ✨ Resultado

### Antes (Problema)

```
ingress-nginx   Syncing   Healthy   ❌ TRAVADO ETERNAMENTE
message: waiting for completion of hook /ServiceAccount/ingress-nginx-admission and 5 more hooks
operationState.phase: Running
```

### Depois (Resolvido)

```
ingress-nginx   Synced    Healthy   ✅ PRONTO
sync.status: Synced
health.status: Healthy
```

---

## 📋 Checklist

- [x] Diagnosticar causa: PreSync hooks travados
- [x] Limpeza imediata: Patch operationState
- [x] Correção permanente: Adicionar retry policy
- [x] Limpeza de hooks: Adicionar hook-delete-policy
- [x] Validação: Application sincronizou com sucesso
- [x] Todos os Applications saudáveis:
  - ✅ azure-workload-identity (Synced/Healthy)
  - ✅ bootstrap (Synced/Healthy)
  - ✅ external-secrets-operator (Synced/Healthy)
  - ✅ ingress-nginx (Synced/Healthy)
  - ✅ cloudgames-prod (Synced/Progressing - pods iniciando)

---

## 🛡️ Prevenção Futura

Para evitar problemas similares com outros Helm charts:

1. **Sempre incluir retry policy**:

   ```yaml
   retry:
     limit: 2
     backoff:
       duration: 5s
       factor: 2
       maxDuration: 5m0s
   ```

2. **Adicionar hook cleanup policy**:

   ```yaml
   syncOptions:
     - PruneLast=true
     - RespectIgnoreDifferences=true
   ```

3. **Monitorar hooks travados**:

   ```bash
   # Ver applications com hooks em execução
   kubectl get applications -n argocd -o json | \
     jq '.items[] | select(.status.operationState.syncResult.resources[] | select(.hookPhase=="Running")) | .metadata.name'
   ```

4. **Limpeza automática se necessário**:
   ```bash
   # Para cada application travada
   kubectl patch application <name> -n argocd \
     --type json \
     -p '[{"op":"replace","path":"/status/operationState","value":null}]'
   ```

---

## 📚 Referências

- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/application-operations/#sync-options)
- [ArgoCD Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
- [NGINX Ingress Helm Chart](https://kubernetes.github.io/ingress-nginx/)

---

## 🎓 Lições Aprendidas

1. **PreSync Hooks requerem cleanup explícito** - Sempre adicionar `hook-delete-policy`
2. **ArgoCD operationState pode ficar preso** - Usar retry policy com timeout
3. **Monitorar status de sync** - Investigate `Syncing` que não progride
4. **Hook completion é assíncrono** - Pode falhar silenciosamente
5. **Helm admissionWebhooks requerem atenção** - Webhook patches não são triviais
