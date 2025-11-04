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

# Check ur app

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

# Then open: https://localhost:8080

# Username: admin

# Password: (from command above)

## Deploy your app with ArgoCD

kubectl apply -f argocd/application.yaml

## How it works:

# - ArgoCD syncs your Git repo every 3 minutes

# - ArgoCD Image Updater checks Docker Hub every 2 minutes for new images

# - When a new image is found, it updates the deployment automatically

# - Rolling update strategy ensures zero downtime (maxUnavailable: 0)

# - Changes are committed back to Git (full audit trail)

## Check ArgoCD Image Updater logs

kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f
