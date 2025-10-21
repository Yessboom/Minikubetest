# Automation Scripts

This folder contains scripts to automate deployment and synchronization of your Kubernetes application.

## Scripts Overview

### 1. `sync-from-git.ps1` - Simple GitOps Sync (Lightweight)

Polls your Git repository and automatically applies manifest changes to your local Minikube cluster.

**Usage:**

Run once (manual sync):
```powershell
.\scripts\sync-from-git.ps1 -Once
```

Run continuously (checks every 60 seconds):
```powershell
.\scripts\sync-from-git.ps1
```

Run with custom interval (e.g., every 30 seconds):
```powershell
.\scripts\sync-from-git.ps1 -IntervalSeconds 30
```

**How it works:**
1. Fetches latest changes from the `Test` branch
2. Compares local and remote commits
3. If changes detected:
   - Pulls latest code
   - Applies `kubernetes/deployment.yaml`
   - Applies `kubernetes/ingress.yaml`
   - Waits for rollout to complete
   - Shows updated pod status

**Best for:**
- Local development on Minikube
- Quick setup without extra tools
- Learning GitOps concepts

**To run automatically on Windows startup:**
1. Create a scheduled task:
   ```powershell
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File D:\User\Minikubetest\scripts\sync-from-git.ps1"
   $trigger = New-ScheduledTaskTrigger -AtStartup
   Register-ScheduledTask -TaskName "Minikube-GitSync" -Action $action -Trigger $trigger -RunLevel Highest
   ```

---

### 2. `setup-argocd.ps1` - Production GitOps with ArgoCD

Installs ArgoCD in your Minikube cluster for automatic, production-grade GitOps.

**Usage:**
```powershell
.\scripts\setup-argocd.ps1
```

**After installation:**
1. Port-forward the ArgoCD UI (in a separate terminal):
   ```powershell
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

2. Access the UI at https://localhost:8080

3. Login with:
   - Username: `admin`
   - Password: (shown in setup script output)

4. Create an Application:
   - Click "New App"
   - **General:**
     - Application Name: `minikube-app`
     - Project: `default`
     - Sync Policy: `Automatic` ✅ (check "Auto-create namespace" and "Prune resources")
   - **Source:**
     - Repository URL: `https://github.com/Yessboom/Minikubetest`
     - Revision: `Test`
     - Path: `kubernetes`
   - **Destination:**
     - Cluster URL: `https://kubernetes.default.svc`
     - Namespace: `default`
   - Click **Create**

**How it works:**
- ArgoCD continuously watches your Git `Test` branch
- When CI pushes an updated `deployment.yaml` with a new image SHA, ArgoCD detects it
- ArgoCD automatically applies the change to your cluster
- Kubernetes performs a rolling update with zero downtime
- ArgoCD UI shows deployment status, history, and diffs

**Best for:**
- Production environments
- Multi-environment setups (dev/staging/prod)
- Team collaboration
- Full audit trail and rollback capabilities

---

## Comparison

| Feature | sync-from-git.ps1 | ArgoCD |
|---------|------------------|--------|
| **Setup time** | 30 seconds | 5 minutes |
| **Resource usage** | Minimal (PowerShell script) | ~400MB RAM for ArgoCD |
| **UI** | No (terminal output) | Yes (web dashboard) |
| **Rollback** | Manual (git revert + run script) | One-click in UI |
| **Multi-app support** | No | Yes |
| **Health checks** | Basic (kubectl rollout status) | Advanced (app health, sync status) |
| **Best for** | Local dev, learning | Production, teams |

---

## Complete Workflow (with either approach)

### Your current CI/CD flow:
1. Edit `index.html` or other files
2. Commit and push to `Dev` branch
3. GitHub Actions:
   - ✅ Runs tests
   - ✅ Builds Docker image with SHA tag
   - ✅ Pushes to Docker Hub
   - ✅ Updates `kubernetes/deployment.yaml` with new SHA
   - ✅ Commits and pushes to `Test` branch

### Automatic deployment:

**With sync-from-git.ps1:**
- Script detects new commit on `Test` branch
- Applies manifests → Kubernetes pulls new image → Rolling update completes
- Total time: ~30-90 seconds after push

**With ArgoCD:**
- ArgoCD detects new commit (polls every 3 minutes by default)
- Auto-syncs manifests → Kubernetes pulls new image → Rolling update
- You see the deployment in ArgoCD UI in real-time
- Total time: ~3-5 minutes after push (can be tuned to 30s with webhook)

---

## Recommended Setup

**For your use case (local Minikube, solo dev):**

1. Start with `sync-from-git.ps1` for immediate results:
   ```powershell
   # In a dedicated PowerShell window, keep this running:
   .\scripts\sync-from-git.ps1 -IntervalSeconds 30
   ```

2. Later, try ArgoCD to experience production GitOps:
   ```powershell
   .\scripts\setup-argocd.ps1
   ```

Both will automatically pull new Docker images when your CI updates the manifest!

---

## Verification

After a successful sync, verify your pods updated:

```powershell
# Check pod image and age
kubectl get pods -l app=nginxdeployment -o wide

# Check actual deployed image
kubectl get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'

# Test the live content
curl.exe -H "Host: firstmilestone.plizgivemefivepoint" http://192.168.59.105/ | Select-String "<h1>"
```

---

## Troubleshooting

**sync-from-git.ps1:**
- Ensure you're on the `Test` branch locally
- Check that `kubectl` is configured to use Minikube context
- If sync fails, run `.\scripts\sync-from-git.ps1 -Once` manually to see errors

**ArgoCD:**
- If app shows "OutOfSync", click "Sync" button in UI
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`
- Ensure auto-sync is enabled in app settings
