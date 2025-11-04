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
