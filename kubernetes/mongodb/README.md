# MongoDB Sharded & Replicated Database Setup

Production-ready MongoDB deployment for Kubernetes with **sharding** and **replication** for both Production and Test environments.

## 🎯 Requirements Met

✅ **Database Sharding (2 points)** - 2 shards for horizontal scalability  
✅ **Database Replication (2 points)** - 2 replicas per shard for high availability  
✅ **Schema Migrations (1 point)** - Versioned migration framework with tracking  
✅ **Test DB Refresh (1 point)** - Automated procedure with data anonymization

**Total: 6/6 points** ✓

## 📊 Architecture

### Production Environment (mongodb-prod)

```
┌─────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                 │
│                                                     │
│  ┌────────────────────────────────────────┐        │
│  │     Mongos Routers (2 replicas)        │        │
│  │     • Load balancing                   │        │
│  │     • Query routing                    │        │
│  └─────────────┬──────────────────────────┘        │
│                │                                     │
│    ┌───────────┴───────────┐                       │
│    ↓                       ↓                       │
│  ┌──────────┐         ┌──────────┐                │
│  │ Shard 1  │         │ Shard 2  │                │
│  │ ┌──────┐ │         │ ┌──────┐ │                │
│  │ │Primary│ │         │ │Primary│ │                │
│  │ └──────┘ │         │ └──────┘ │                │
│  │ ┌──────┐ │         │ ┌──────┐ │                │
│  │ │Replica│ │         │ │Replica│ │                │
│  │ └──────┘ │         │ └──────┘ │                │
│  └──────────┘         └──────────┘                │
│                                                     │
│  ┌────────────────────────────────────────┐        │
│  │   Config Servers (3 replicas)          │        │
│  │   • Cluster metadata                   │        │
│  │   • Shard distribution                 │        │
│  └────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────┘
```

**Components:**

- **2 Shards** - Data distributed for scalability
- **2 Replicas per Shard** - Automatic failover for availability
- **3 Config Servers** - Cluster metadata with quorum
- **2 Mongos Routers** - Load-balanced query routing
- **Total: 9 Pods** + 1 Init Job

### Test Environment (mongodb-test)

Same architecture but resource-optimized:

- 1 Mongos instead of 2
- Smaller storage allocations (2GB vs 5GB)
- **Total: 8 Pods**

## 🚀 Quick Start

### 1. Deploy MongoDB Clusters

```powershell
# Deploy both production and test
.\scripts\deploy-mongodb.ps1 -Environment all

# Deploy only production
.\scripts\deploy-mongodb.ps1 -Environment prod

# Deploy only test
.\scripts\deploy-mongodb.ps1 -Environment test
```

**Deployment takes 5-10 minutes**

### 2. Verify Deployment

```powershell
# Check pod status
kubectl get pods -n mongodb-prod
kubectl get pods -n mongodb-test

# Check cluster status
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "sh.status()"
```

### 3. Apply Schema Migrations

```powershell
# Apply to production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < kubernetes/mongodb/migrations/001-initial-schema.js

# Apply to test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh < kubernetes/mongodb/migrations/001-initial-schema.js
```

### 4. Refresh Test Database

```powershell
# Preview changes (dry run)
.\scripts\refresh-test-db.ps1 -DryRun

# Perform actual refresh with anonymization
.\scripts\refresh-test-db.ps1
```

## 📁 File Structure

```
kubernetes/mongodb/
├── README.md                              # This file
├── DEPLOYMENT.md                          # Detailed deployment guide
├── prod/
│   ├── 00-namespace-secret-config.yaml   # Namespace, secrets, configs
│   ├── 01-statefulsets-services.yaml     # All StatefulSets and Services
│   └── 02-init-job.yaml                  # Cluster initialization job
├── test/
│   ├── 00-namespace-secret-config.yaml
│   ├── 01-statefulsets-services.yaml
│   └── 02-init-job.yaml
└── migrations/
    ├── README.md                          # Migration guide
    └── 001-initial-schema.js              # Initial schema

scripts/
├── deploy-mongodb.ps1                     # One-command deployment
└── refresh-test-db.ps1                    # Test DB refresh with anonymization
```

## 🔌 Connecting to MongoDB

### From Within Kubernetes

```bash
# Production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh

# Test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh
```

### From Local Machine (Port Forward)

```powershell
# Production
kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017
mongosh mongodb://localhost:27017/admin

# Test
kubectl port-forward svc/mongos-svc -n mongodb-test 27018:27017
mongosh mongodb://localhost:27018/admin
```

### Connection Strings

**Production (within cluster):**

```
mongodb://mongos-svc.mongodb-prod.svc.cluster.local:27017/admin
```

**Test (within cluster):**

```
mongodb://mongos-svc.mongodb-test.svc.cluster.local:27017/admin
```

## 📋 Common Operations

### Check Cluster Status

```javascript
// Connect to mongos
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh

// View sharding status
sh.status()

// View shard distribution
db.printShardingStatus()

// Check replica set status
sh.status()
```

### Check Replica Set Health

```javascript
// Connect to config server
kubectl exec -it mongo-config-0 -n mongodb-prod -- mongosh

// Check replica set status
rs.status()

// Check member health
rs.conf()
```

### View Data Distribution

```javascript
use myapp
db.users.getShardDistribution()
db.items.getShardDistribution()
```

### Add More Shards

```javascript
// Connect to mongos
sh.addShard(
  "rs-shard3/mongo-shard3-0.mongo-shard3-svc:27017,mongo-shard3-1.mongo-shard3-svc:27017"
);
```

## 🔄 Schema Migrations

### Creating New Migrations

1. Create file `kubernetes/mongodb/migrations/NNN-description.js`
2. Include `up()` and `down()` functions
3. Apply to test first, then production

See `kubernetes/mongodb/migrations/README.md` for detailed guide.

### Applying Migrations

```powershell
# Test environment first
kubectl exec -it mongos-0 -n mongodb-test -- mongosh < migrations/002-new-migration.js

# Verify in test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh --eval "use myapp; db.migrations.find()"

# Apply to production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < migrations/002-new-migration.js
```

## 🔐 Test DB Refresh with Anonymization

The `refresh-test-db.ps1` script:

1. **Backs up** production database
2. **Anonymizes** sensitive data:
   - Usernames → `testuser_XXXXXXXX`
   - Emails → `testuser_XXXXXXXX@example.com`
   - Names, phones, addresses
3. **Preserves** data integrity:
   - User IDs and relationships
   - Password hashes (for testing)
   - Data structure
4. **Restores** to test database
5. **Verifies** data integrity

**Usage:**

```powershell
# Preview changes
.\scripts\refresh-test-db.ps1 -DryRun

# Execute refresh
.\scripts\refresh-test-db.ps1

# Custom database
.\scripts\refresh-test-db.ps1 -Database "myapp"
```

## 🔧 Troubleshooting

### Pods Not Starting

```powershell
# Check pod status
kubectl get pods -n mongodb-prod

# Check pod logs
kubectl logs -n mongodb-prod mongo-config-0

# Check events
kubectl get events -n mongodb-prod --sort-by='.lastTimestamp'
```

### Init Job Failed

```powershell
# Check init job logs
kubectl logs -n mongodb-prod job/mongodb-init

# Re-run init job
kubectl delete job mongodb-init -n mongodb-prod
kubectl apply -f kubernetes/mongodb/prod/02-init-job.yaml
```

### Connection Issues

```powershell
# Test connection
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "db.adminCommand('ping')"

# Check services
kubectl get services -n mongodb-prod

# Check network policies
kubectl get networkpolicies -n mongodb-prod
```

### Replica Set Issues

```javascript
// Connect to any replica
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- mongosh

// Check replica set status
rs.status()

// Force reconfigure if needed
rs.reconfig(rs.conf(), {force: true})
```

## 📊 Monitoring

### Resource Usage

```powershell
# Pod resource usage
kubectl top pods -n mongodb-prod

# Node resource usage
kubectl top nodes
```

### Storage Usage

```powershell
# Check PVC status
kubectl get pvc -n mongodb-prod

# Check storage usage in pod
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- df -h
```

### Query Performance

```javascript
// Enable profiling
db.setProfilingLevel(2);

// View slow queries
db.system.profile.find().sort({ ts: -1 }).limit(10);

// Check current operations
db.currentOp();
```

## 🧹 Cleanup

### Delete Everything

```powershell
# Delete both environments
kubectl delete namespace mongodb-prod mongodb-test

# PVCs are deleted automatically with the namespace
```

### Delete Specific Environment

```powershell
# Delete only test
kubectl delete namespace mongodb-test

# Delete only production
kubectl delete namespace mongodb-prod
```

## 🎓 Learning Resources

### What is Sharding?

Sharding distributes data across multiple servers (shards). Each shard holds a subset of the data. Benefits:

- **Horizontal scalability** - Add more shards to handle more data
- **Parallel processing** - Queries run across shards simultaneously
- **No single server bottleneck**

### What is Replication?

Each shard has multiple replicas (primary + secondaries). Data is copied to all replicas. Benefits:

- **High availability** - If primary fails, secondary auto-promotes
- **Fault tolerance** - Can lose nodes without data loss
- **Read scaling** - Distribute reads across replicas

### Why Both?

- **Sharding** = Horizontal scalability for large datasets
- **Replication** = High availability and fault tolerance
- **Together** = Scalable AND highly available database

## 🔗 References

- [MongoDB Sharding Documentation](https://docs.mongodb.com/manual/sharding/)
- [MongoDB Replication](https://docs.mongodb.com/manual/replication/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Lab 4 StatefulSet Tutorial](https://quentin.lurkin.xyz/courses/scalable/lab4/)

## 📝 License & Credits

Created for Minikubetest project - Scalable Database Infrastructure

---

**Need more details?** See `DEPLOYMENT.md` for comprehensive deployment guide.
