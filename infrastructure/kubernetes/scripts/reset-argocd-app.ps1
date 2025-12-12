<#
.SYNOPSIS
  Cleans ArgoCD cache and recreates application.
.DESCRIPTION
  Deletes the user-app application, restarts the repo-server to clear cache,
  and recreates the application.
.EXAMPLE
  .\reset-argocd-app.ps1
#>

Write-Host "1. Deleting user-app application..." -ForegroundColor Yellow
kubectl delete application user-app -n argocd

Write-Host "
2. Restarting argocd-repo-server to clear cache..." -ForegroundColor Yellow
kubectl rollout restart deployment argocd-repo-server -n argocd

Write-Host "
3. Waiting for repo-server to be ready..." -ForegroundColor Yellow
kubectl rollout status deployment argocd-repo-server -n argocd

Write-Host "
4. Recreating user-app application..." -ForegroundColor Yellow
kubectl apply -f C:\Projects\tc-cloudgames-solution\infrastructure\kubernetes\manifests\application-user.yaml

Write-Host "
5. Checking status..." -ForegroundColor Green
kubectl get application user-app -n argocd
