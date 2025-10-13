#  Set up:
##  Minikube
If you haven't installed it yet, Minikube is available [here](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download) .

Start Minikube
```bash
minikube start
```

### Ingress Controller:
Enable Ingress
```bash
minikube addons enable ingress
```
Verify that the NGINX Ingress controller is running
```bash
kubectl get pods -n ingress-nginx
```


Configure Docker to use Minikube's daemon
```bash
minikube docker-env | Invoke-Expression
```


# Start the project
Deploy App 
```bash
kubectl apply -f deployment.yaml
kubectl apply -f ingress.yaml
```

Wait for deployment to be ready
```bash
kubectl rollout status deployment/nginx-deployment
```

# Access the project 
Access you app 
```bash
kubectl port-forward service/nginxservice 8080:80
```
