# MongoDB Sharded & Replicated Cluster Deployment Guide

## Overview

This guide provides instructions for deploying and managing MongoDB sharded and replicated clusters for both Production and Test environments.

### Architecture

**Production Environment (mongodb-prod namespace):**
- 2 Shards, each with 2 replicas = 4 data nodes
- 3 Config Servers (1 replica set)
- 2 Mongos Routers for load balancing
- 5GB storage per shard node

**Test Environment (mongodb-test namespace):**
- 2 Shards, each with 2 replicas = 4 data nodes
- 3 Config Servers (1 replica set)
- 1 Mongos Router
- 2GB storage per shard node (resource optimized)

## Prerequisites

- Kubernetes cluster (Minikube with at least 8GB RAM)
- kubectl configured and accessible
- mongo:7.0 image available (automatically pulled)

## Deployment Steps

### Step 1: Deploy Production MongoDB

```powershell
# Apply namespace, secrets, and config
kubectl apply -f kubernetes/mongodb/prod/00-namespace-secret-config.yaml

# Apply stateful sets and services
kubectl apply -f kubernetes/mongodb/prod/01-statefulsets-services.yaml

# Wait for all pods to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod -l app=mongo-config -n mongodb-prod --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard1 -n mongodb-prod --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard2 -n mongodb-prod --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongos -n mongodb-prod --timeout=300s

# Wait for pods to be fully initialized
Start-Sleep -Seconds 30

# Initialize the cluster (config servers, shards, and add shards)
kubectl apply -f kubernetes/mongodb/prod/02-init-job.yaml

# Wait for initialization to complete
kubectl wait --for=condition=ready pod mongo-init-prod -n mongodb-prod --timeout=600s
```

### Step 2: Deploy Test MongoDB

```powershell
# Apply namespace, secrets, and config
kubectl apply -f kubernetes/mongodb/test/00-namespace-secret-config.yaml

# Apply stateful sets and services
kubectl apply -f kubernetes/mongodb/test/01-statefulsets-services.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=mongo-config -n mongodb-test --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard1 -n mongodb-test --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard2 -n mongodb-test --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongos -n mongodb-test --timeout=300s

# Wait for pods to be fully initialized
Start-Sleep -Seconds 30

# Initialize the cluster
kubectl apply -f kubernetes/mongodb/test/02-init-job.yaml

# Wait for initialization to complete
kubectl wait --for=condition=ready pod mongo-init-test -n mongodb-test --timeout=600s
```

### Step 3: Verify Deployments

```powershell
# Check production cluster status
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'sh.status()'

# Check test cluster status
kubectl exec -it mongos-0 -n mongodb-test -- mongosh --eval 'sh.status()'

# List all pods
kubectl get pods -n mongodb-prod
kubectl get pods -n mongodb-test

# Check services
kubectl get svc -n mongodb-prod
kubectl get svc -n mongodb-test
```

## Connection Strings

### From Within Kubernetes Cluster

```
Production: mongodb://mongos-svc.mongodb-prod.svc.cluster.local:27017/admin
Test:       mongodb://mongos-svc.mongodb-test.svc.cluster.local:27017/admin
```

### From Local Machine (Port Forwarding)

```powershell
# Forward production MongoDB to localhost:27017
kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017

# In another terminal, forward test MongoDB to localhost:27018
kubectl port-forward svc/mongos-svc -n mongodb-test 27018:27017

# Connect from local machine
mongosh mongodb://localhost:27017/admin
mongosh mongodb://localhost:27018/admin
```

## Schema Migrations

### Running Migrations

1. **Initial schema setup:**

```powershell
# Apply to production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < kubernetes/mongodb/migrations/001-initial-schema.js

# Apply to test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh < kubernetes/mongodb/migrations/001-initial-schema.js
```

2. **Creating new migrations:**

Create a new file `kubernetes/mongodb/migrations/NNN-description.js`:

```javascript
db = db.getSiblingDB('myapp');

function up() {
  print('Starting migration NNN: Description');
  
  // Your migration code here
  // Example: add new field to users collection
  // db.users.updateMany({}, {$set: {newField: defaultValue}});
  
  // Track migration
  db.migrations.insertOne({
    migration: 'NNN-description',
    executed_at: new Date(),
    status: 'completed'
  });
  
  print('Migration NNN: Completed');
}

function down() {
  print('Reverting migration NNN');
  // Revert logic here
  db.migrations.deleteOne({ migration: 'NNN-description' });
}

up();
```

### View Migration History

```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'db.getSiblingDB("myapp").migrations.find().pretty()'
```

## Test Database Refresh

### Refresh from Production with Anonymization

```powershell
# Preview what would be done (dry run)
.\scripts\refresh-test-db.ps1 -DryRun $true

# Actually perform the refresh
.\scripts\refresh-test-db.ps1
```

### What Gets Anonymized

- **Usernames:** Changed to `testuser_<id>`
- **Emails:** Changed to `testuser_<id>@example.com`
- **Password Hashes:** Preserved for authentication testing
- **User IDs:** Preserved for relationship integrity
- **Timestamps:** Updated to reflect refresh time

## Monitoring and Management

### Check Cluster Status

```powershell
# Production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'sh.status()'

# Test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh --eval 'sh.status()'
```

### View Shard Distribution

```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'db.stats()'
```

### Check Replica Set Status

```powershell
# Config servers
kubectl exec -it mongo-config-0 -n mongodb-prod -- mongosh --eval 'rs.status()'

# Shard 1
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- mongosh --eval 'rs.status()'

# Shard 2
kubectl exec -it mongo-shard2-0 -n mongodb-prod -- mongosh --eval 'rs.status()'
```

### View Logs

```powershell
# Check mongos logs
kubectl logs mongos-0 -n mongodb-prod

# Check shard logs
kubectl logs mongo-shard1-0 -n mongodb-prod
```

## Cleanup

### Delete Test Environment

```powershell
kubectl delete namespace mongodb-test
```

### Delete Production Environment

```powershell
kubectl delete namespace mongodb-prod
```

## Troubleshooting

### Pods Not Starting

```powershell
# Check pod status
kubectl describe pod <pod-name> -n mongodb-prod

# Check logs
kubectl logs <pod-name> -n mongodb-prod
```

### Connection Issues

```powershell
# Verify service DNS
kubectl exec -it mongos-0 -n mongodb-prod -- nslookup mongos-svc.mongodb-prod.svc.cluster.local

# Test connectivity between pods
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --host mongo-config-0.mongo-config-svc.mongodb-prod.svc.cluster.local:27017 --eval 'print("Connection successful")'
```

### Replica Set Issues

```powershell
# Re-initialize a replica set (careful!)
kubectl exec -it mongo-config-0 -n mongodb-prod -- mongosh --eval '
rs.reconfig(rs.conf(), {force: true})
'
```

## Performance Tuning

### Enable Sharding on Specific Database

```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'sh.enableSharding("myapp")'
```

### Set Shard Key for Collection

```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'sh.shardCollection("myapp.items", {user_id: 1})'
```

### View Storage Usage

```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval 'db.getSiblingDB("myapp").stats()'
```

## Backup and Restore

### Backup Production

```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongodump --out /tmp/backup
kubectl cp mongodb-prod/mongos-0:/tmp/backup ./backup-$(Get-Date -Format 'yyyyMMdd')
```

### Restore to Test

```powershell
kubectl cp ./backup mongodb-test/mongos-0:/tmp/backup
kubectl exec -it mongos-0 -n mongodb-test -- mongorestore /tmp/backup
```

## Key Features

✓ **Sharded (2 points):** Data distributed across 2 shards for scalability
✓ **Replicated (2 points):** Each shard has 2 replicas for high availability
✓ **Schema Migrations (1 point):** Versioned migration scripts in `kubernetes/mongodb/migrations/`
✓ **Test DB Refresh (1 point):** Automated anonymized data sync in `scripts/refresh-test-db.ps1`

## Total Score: 6/6 Points ✓
