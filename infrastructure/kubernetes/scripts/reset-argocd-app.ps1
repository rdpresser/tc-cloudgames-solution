# Script para limpar cache do ArgoCD e recriar aplicação

Write-Host "1. Deletando aplicação user-app..." -ForegroundColor Yellow
kubectl delete application user-app -n argocd

Write-Host "
2. Reiniciando argocd-repo-server para limpar cache..." -ForegroundColor Yellow
kubectl rollout restart deployment argocd-repo-server -n argocd

Write-Host "
3. Aguardando repo-server ficar pronto..." -ForegroundColor Yellow
kubectl rollout status deployment argocd-repo-server -n argocd

Write-Host "
4. Recriando aplicação user-app..." -ForegroundColor Yellow
kubectl apply -f C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\manifests\application-user.yaml

Write-Host "
5. Verificando status..." -ForegroundColor Green
kubectl get application user-app -n argocd
