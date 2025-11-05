# Scallable application project

The goal of this project is to set up a professional-grade infrastructure on an on-premise Kubernetes cluster (initially running locally on each student’s machine). The deliverables needed are available [here](http://https://quentin.lurkin.xyz/courses/scalable/project2526/ "here")

This project is running on Docker Desktop with kubernetes.
It uses ArgoCD for a CI/CD image pulling

# Setting up the project

## install Ingress

`kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s`

## Build and push image

`docker build -t yessboom/my-custom-nginx:latest .
docker login
docker push yessboom/my-custom-nginx:latest`

## Then build it

docker build -t my-custom-nginx:local .

## Apply manifests

`kubectl apply -f kubernetes/deployment.yaml
kubectl rollout status deployment/nginx-deployment
kubectl apply -f kubernetes/ingress.yaml`

# Check ur app !!

Just go to http://localhost

# Install Metrics Server (for Dashboard metrics)

`kubectl apply -f metrics-server.yaml
kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes`

# Run ur dashboard

`kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl -n kubernetes-dashboard rollout status deploy/kubernetes-dashboard
kubectl apply -f kubernetes/dashboard-admin.yaml`

### get login token

`kubectl -n kubernetes-dashboard create token admin-user`

### open dashboard

`kubectl proxy`

### In another terminal

`start http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`

And paste your login token

# Install ArgoCD (GitOps)

ArgoCD check every 3min if a new commit has been pushed. If it's the case, it compares the SHA of its pods with the ones from the new commit and update the image if needed.
There is one check per branch (Prod, Test and Dev)

## Install ArgoCD

`kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd`

## Get ArgoCD password

`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($\_)) }`

## Access ArgoCD UI !! There is one thing for each branchs

`kubectl port-forward svc/argocd-server -n argocd 8080:443`

Then open: https://localhost:8080 !

Username: admin

Password: (from command above)

## Deploy your app with ArgoCD

`kubectl apply -f argocd/application.yaml`

## How it works:

## Check in the console the different images for your environnements:

`kubectl get deployments -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image | Select-String "nginx-deployment"`

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
