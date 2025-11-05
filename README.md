# Scallable application project

The goal of this project is to set up a professional-grade infrastructure on an on-premise Kubernetes cluster (initially running locally on each student’s machine). The deliverables needed are available [here](http://https://quentin.lurkin.xyz/courses/scalable/project2526/ "here")

This project is running on Docker Desktop with kubernetes.
It uses ArgoCD for a CI/CD image pulling

# Setting up and launching the app

## installing Ingress

`kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=180s`

## Build and push image

`docker build -t yessboom/my-custom-nginx:latest .
docker login
docker push yessboom/my-custom-nginx:latest`

## Apply manifests

`kubectl apply -f kubernetes/deployment.yaml
kubectl rollout status deployment/nginx-deployment
kubectl apply -f kubernetes/ingress.yaml`

## Check ur app !!

Just go to http://localhost


# Dashboard

## Setting up dashboard

`kubectl apply -f metrics-server.yaml
kubectl -n kube-system rollout status deploy/metrics-server
kubectl top nodes`

## Apply dashboard manifest

`kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl -n kubernetes-dashboard rollout status deploy/kubernetes-dashboard
kubectl apply -f kubernetes/dashboard-admin.yaml`

## Connect to Dashboard
### Get login tokens
`kubectl -n kubernetes-dashboard create token admin-user`

### Open dashboard
`kubectl proxy`

### Access Dashboard on desktop

`start http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`
will open a new window on your web browser where you will need to pas the login tokens to connect

# ArgoCD (GitOps)

ArgoCD check every 3min if a new commit has been pushed. If it's the case, it compares the SHA of its pods with the ones from the new commit and update the image if needed.
There is one check per branch (Prod, Test and Dev)
#### How does it work
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

## Install ArgoCD

`kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd`

## Get ArgoCD password

`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($\_)) }`

## Access ArgoCD UI

`kubectl port-forward svc/argocd-server -n argocd 8080:443`

Then open: https://localhost:8080 !

Username: admin

Password: (from command above)

## Deploy your app with ArgoCD

`kubectl apply -f argocd/application.yaml`

## Troubleshooting
### Check in the console the different images for your environnements:

`kubectl get deployments -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image | Select-String "nginx-deployment"`

# CI/CD
When pushing commits to Dev branch, github action will automatically run all the tests. If they pass, it will build and push the image to Docker Hub and, before merging the changes into the Test branch. 
This merge will be noticed by ArgoCD who will do a no-downtime rollout. 

# Database
The databases are not used in this project. They exist tho, because I would lose points if they didn't. Ain't that great? In the meantime here are 2 DBs, one Prod and one Test, replicated and sharded
## Setting up the DB
`.\scripts\deploy-mongodb-simple.ps1 -Environment all`
will deploy both Prod and Test, but you can chose which one to deploy by using 
`\scripts\deploy-mongodb-simple.ps1 -Environment prod
.\scripts\deploy-mongodb-simple.ps1 -Environment test`

These commands will launch the installation scripts in kubernetes/mongodb folder. 
## Check ur pods
Still not sure it's correctly installed ? You can easily check your pods 
`kubectl get pods -A | Select-String mongodb`

## Access DB through GUI

`kubectl port-forward -n mongodb-test svc/mongos-svc 27017:27017
kubectl port-forward -n mongodb-prod svc/mongos-svc 27018:27017`
Will forward the Test DB to 27017, and Prod DB to 27018. You can now easily connect to them in MongoDB Compass by clicking on connect and inputing "mongodb://localhost:27017/" or "mongodb://localhost:27018/"


## Export from prod and anonymize
Yeah it's not done. Better luck next time kiddo

