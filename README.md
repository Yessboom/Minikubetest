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

