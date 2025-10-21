# Install and configure ArgoCD in your Minikube cluster
# ArgoCD will automatically sync your Git repo to the cluster

Write-Host "Installing ArgoCD..." -ForegroundColor Cyan

# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
Write-Host "`nWaiting for ArgoCD pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
$adminPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "`n✅ ArgoCD installed successfully!" -ForegroundColor Green
Write-Host "`nAccess ArgoCD UI:" -ForegroundColor Cyan
Write-Host "  1. Run this in another terminal:" -ForegroundColor White
Write-Host "     kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Gray
Write-Host "  2. Open: https://localhost:8080" -ForegroundColor White
Write-Host "  3. Login with:" -ForegroundColor White
Write-Host "     Username: admin" -ForegroundColor Gray
Write-Host "     Password: $adminPassword" -ForegroundColor Gray

Write-Host "`n📝 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Access the ArgoCD UI" -ForegroundColor White
Write-Host "  2. Create a new App pointing to your Git repo:" -ForegroundColor White
Write-Host "     - Repository: https://github.com/Yessboom/Minikubetest" -ForegroundColor Gray
Write-Host "     - Path: kubernetes" -ForegroundColor Gray
Write-Host "     - Branch: Test" -ForegroundColor Gray
Write-Host "     - Cluster: https://kubernetes.default.svc" -ForegroundColor Gray
Write-Host "     - Namespace: default" -ForegroundColor Gray
Write-Host "  3. Enable auto-sync in the app settings" -ForegroundColor White
Write-Host "`nArgoCD will now automatically deploy changes from your Test branch!" -ForegroundColor Green
