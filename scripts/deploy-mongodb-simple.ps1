# MongoDB Deployment Script - Simplified Version
param(
    [ValidateSet('prod', 'test', 'all')]
    [string]$Environment = 'all'
)

$ErrorActionPreference = 'Stop'

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'MongoDB Deployment' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Deploy production
if ($Environment -eq 'all' -or $Environment -eq 'prod') {
    Write-Host 'Deploying Production Environment...' -ForegroundColor Green
    kubectl apply -f kubernetes/mongodb/prod/
    Write-Host 'Production deployed!' -ForegroundColor Green
}

# Deploy test
if ($Environment -eq 'all' -or $Environment -eq 'test') {
    Write-Host 'Deploying Test Environment...' -ForegroundColor Green
    kubectl apply -f kubernetes/mongodb/test/
    Write-Host 'Test deployed!' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Deployment complete!' -ForegroundColor Cyan
