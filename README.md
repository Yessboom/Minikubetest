# install Ingress

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s

# Build and push image

docker build -t yessboom/my-custom-nginx:latest .
docker login
docker push yessboom/my-custom-nginx:latest

## Then build it

docker build -t my-custom-nginx:local .

## Apply manifests

kubectl apply -f kubernetes/deployment.yaml
kubectl rollout status deployment/nginx-deployment
kubectl apply -f kubernetes/ingress.yaml

# Check ur app !!

Just go to http://localhost

# Install Metrics Server (for Dashboard metrics)

kubectl apply -f metrics-server.yaml
kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes

# Run ur dashboard

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl -n kubernetes-dashboard rollout status deploy/kubernetes-dashboard
kubectl apply -f kubernetes/dashboard-admin.yaml

### get login token

kubectl -n kubernetes-dashboard create token admin-user

### open dashboard

kubectl proxy

### In another terminal

start http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

And paste your login token

# Install ArgoCD (GitOps + Auto Image Updates)

## Install ArgoCD

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

## Install ArgoCD Image Updater (auto-detects new images)

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

## Get ArgoCD password

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($\_)) }

## Access ArgoCD UI

kubectl port-forward svc/argocd-server -n argocd 8080:443

# Then open: https://localhost:8080 !

# Username: admin

# Password: (from command above)

## Deploy your app with ArgoCD

kubectl apply -f argocd/application.yaml

## How it works:

**Multi-Environment Setup:**

- **Dev Environment** (namespace: dev) - Syncs from `Dev` branch
- **Test Environment** (namespace: test) - Syncs from `Test` branch
- **Prod Environment** (namespace: prod) - Syncs from `main` branch

**Deployment Workflow:**

1. Build and push image to DockerHub with git commit SHA as tag
2. Update the image tag in `kubernetes/deployment.yaml` with the new SHA
3. Commit and push to the target branch (Dev/Test/main)
4. ArgoCD detects the Git change (polls every 3 minutes)
5. ArgoCD automatically syncs and deploys with zero downtime

**Example:**

- Update Test environment: Push to `Test` branch with new image SHA
- Update Prod environment: Push to `main` branch with new image SHA
- Update Dev environment: Push to `Dev` branch with new image SHA

- Rolling update strategy ensures zero downtime (maxUnavailable: 0)
- Full Git history for audit trail

## Build and Deploy Workflow

### For Test Environment:

```powershell
# Switch to Test branch
git checkout Test

# Build with git commit SHA as tag
$commitSHA = git rev-parse HEAD
docker build -t yessboom/my-custom-nginx:$commitSHA .
docker push yessboom/my-custom-nginx:$commitSHA

# Update deployment.yaml with new image tag
# Edit kubernetes/deployment.yaml and change:
# image: yessboom/my-custom-nginx:<NEW_SHA>

# Commit and push
git add kubernetes/deployment.yaml
git commit -m "Update Test environment to $commitSHA"
git push origin Test

# ArgoCD will auto-sync within 3 minutes
```

### For Production Environment:

```powershell
# Switch to main branch
git checkout main

# Build with git commit SHA as tag
$commitSHA = git rev-parse HEAD
docker build -t yessboom/my-custom-nginx:$commitSHA .
docker push yessboom/my-custom-nginx:$commitSHA

# Update deployment.yaml with new image tag
# Edit kubernetes/deployment.yaml and change:
# image: yessboom/my-custom-nginx:<NEW_SHA>

# Commit and push
git add kubernetes/deployment.yaml
git commit -m "Update Production to $commitSHA"
git push origin main

# ArgoCD will auto-sync within 3 minutes
```

### For Dev Environment:

```powershell
# Switch to Dev branch
git checkout Dev

# Build with git commit SHA as tag
$commitSHA = git rev-parse HEAD
docker build -t yessboom/my-custom-nginx:$commitSHA .
docker push yessboom/my-custom-nginx:$commitSHA

# Update deployment.yaml with new image tag
# Edit kubernetes/deployment.yaml and change:
# image: yessboom/my-custom-nginx:<NEW_SHA>

# Commit and push
git add kubernetes/deployment.yaml
git commit -m "Update Dev environment to $commitSHA"
git push origin Dev

# ArgoCD will auto-sync within 3 minutes
```

## View Applications Status

```powershell
# Check all environments
kubectl get applications -n argocd

# View specific app details
kubectl get application minikubetest-dev -n argocd
kubectl get application minikubetest-test -n argocd
kubectl get application minikubetest-prod -n argocd

# Force sync manually if needed
kubectl patch application minikubetest-dev -n argocd --type merge -p '{"operation":{"sync":{}}}'
kubectl patch application minikubetest-test -n argocd --type merge -p '{"operation":{"sync":{}}}'
kubectl patch application minikubetest-prod -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

## Check ArgoCD Sync Status

```powershell
# Watch ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```
