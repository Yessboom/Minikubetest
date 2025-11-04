# GitHub Secrets Setup for CI/CD

To enable the automated CI/CD pipeline, you need to add the following secrets to your GitHub repository:

## Required Secrets

Go to your repository on GitHub → Settings → Secrets and variables → Actions → New repository secret

### 1. DOCKER_USERNAME

- **Value**: Your Docker Hub username (e.g., `yessboom`)
- **Used for**: Pushing Docker images to Docker Hub

### 2. DOCKER_PASSWORD

- **Value**: Your Docker Hub password or access token
- **Used for**: Authenticating to Docker Hub
- **Recommended**: Use a Docker Hub access token instead of password
  - Create one at: https://hub.docker.com/settings/security

### 3. ARGOCD_SERVER (Optional - for ArgoCD integration)

- **Value**: Your ArgoCD server address (e.g., `localhost:8080` or `argocd.yourdomain.com`)
- **Used for**: Triggering ArgoCD sync after deployment
- **Note**: Leave empty if not using ArgoCD

### 4. ARGOCD_PASSWORD (Optional - for ArgoCD integration)

- **Value**: Your ArgoCD admin password
- **Used for**: Authenticating to ArgoCD to trigger syncs
- **Get it with**: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

## CI/CD Workflow

When you push to the **Dev** branch:

1. ✅ **Run Tests** - Jest tests must pass
2. 🐳 **Build Docker Image** - Create and push to Docker Hub with:
   - Tag: `latest`
   - Tag: `<commit-sha>` (for version tracking)
3. 📝 **Update Manifest** - Updates `kubernetes/deployment.yaml` with new image SHA
4. 📦 **Merge to Test** - Automatically merges Dev → Test branch
5. 🔄 **Trigger ArgoCD** - (Optional) Forces ArgoCD to sync and deploy
6. 💬 **Comment** - Posts deployment summary on the commit

## Workflow Protection

The workflow uses `[skip ci]` in commit messages to prevent infinite loops when updating manifests.

## Testing the Workflow

```powershell
# Make a change and push to Dev
git checkout Dev
echo "# Test change" >> README.md
git add .
git commit -m "test: trigger CI/CD pipeline"
git push origin Dev
```

Then watch the Actions tab in GitHub to see the pipeline run!

## Troubleshooting

- **Docker push fails**: Check DOCKER_USERNAME and DOCKER_PASSWORD secrets
- **Merge fails**: Ensure you have write permissions on the repository
- **ArgoCD sync fails**: Check ARGOCD_SERVER and ARGOCD_PASSWORD values
- **Tests fail**: Fix the code and push again - deployment won't happen until tests pass
