# Sync Kubernetes manifests from Git and apply to local cluster
# Run this in a loop or as a scheduled task to auto-update your Minikube cluster

param(
    [int]$IntervalSeconds = 60,
    [switch]$Once
)

$repoPath = "D:\User\Minikubetest"

function Sync-Manifests {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Checking for updates..." -ForegroundColor Cyan
    
    # Save current directory
    Push-Location $repoPath
    
    try {
        # Fetch latest from origin
        git fetch origin 2>&1 | Out-Null
        
        # Get current and remote commit for Test branch
        $localCommit = git rev-parse HEAD
        $remoteCommit = git rev-parse origin/Test
        
        if ($localCommit -ne $remoteCommit) {
            Write-Host "  New changes detected! Pulling and applying..." -ForegroundColor Yellow
            
            # Pull latest
            git pull origin Test
            
            # Apply updated manifests
            Write-Host "  Applying Deployment..." -ForegroundColor Green
            kubectl apply -f kubernetes/deployment.yaml
            
            Write-Host "  Applying Ingress..." -ForegroundColor Green
            kubectl apply -f kubernetes/ingress.yaml
            
            # Wait for rollout
            Write-Host "  Waiting for rollout to complete..." -ForegroundColor Green
            kubectl rollout status deploy/nginx-deployment --timeout=180s
            
            # Show updated pods
            Write-Host "`n  Updated pods:" -ForegroundColor Green
            kubectl get pods -l app=nginxdeployment -o wide
            
            Write-Host "`n✅ Deployment updated successfully!" -ForegroundColor Green
        } else {
            Write-Host "  No changes detected." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ❌ Error: $_" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
}

# Main loop
if ($Once) {
    Sync-Manifests
} else {
    Write-Host "Starting continuous sync (checking every $IntervalSeconds seconds)..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Yellow
    
    while ($true) {
        Sync-Manifests
        Start-Sleep -Seconds $IntervalSeconds
    }
}
