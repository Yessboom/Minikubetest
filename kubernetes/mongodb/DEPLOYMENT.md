# MongoDB Sharded Cluster - Detailed Deployment Guide

Complete guide for deploying, managing, and maintaining MongoDB sharded clusters in Kubernetes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Deep Dive](#architecture-deep-dive)
3. [Deployment Steps](#deployment-steps)
4. [Configuration Details](#configuration-details)
5. [Schema Management](#schema-management)
6. [Test Database Refresh](#test-database-refresh)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Performance Tuning](#performance-tuning)
9. [Backup & Recovery](#backup--recovery)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

1. **Kubernetes Cluster** (Minikube, Kind, or cloud provider)

   ```powershell
   # Verify cluster access
   kubectl cluster-info
   ```

2. **kubectl** - Kubernetes CLI

   ```powershell
   kubectl version --client
   ```

3. **mongosh** - MongoDB Shell (for local operations)

   ```powershell
   mongosh --version
   ```

4. **PowerShell 5.1+** (Windows) or Bash (Linux/Mac)

### Cluster Requirements

- **CPU**: Minimum 4 cores available
- **Memory**: Minimum 8GB RAM available
- **Storage**: Dynamic PV provisioning enabled (or manual PV creation)
- **Nodes**: Minimum 2 nodes recommended

### Verify Prerequisites

```powershell
# Check if dynamic PV provisioning is available
kubectl get storageclass

# Check available resources
kubectl top nodes
```

---

## Architecture Deep Dive

### Component Breakdown

#### 1. Config Servers (3 replicas)

**Purpose**: Store cluster metadata and configuration

```yaml
Replica Set: rs-config
Members: 3 (for quorum-based decisions)
Storage: 1-2GB per server
Resources: 256Mi RAM, 100m CPU
```

**Why 3?** Provides fault tolerance with majority-based consensus. Can survive 1 node failure.

#### 2. Shard Servers (2 shards × 2 replicas)

**Purpose**: Store actual data, distributed across shards

```yaml
Shard 1:
  Replica Set: rs-shard1
  Members: 2 (Primary + Secondary)
  Storage: 2-5GB per replica
  Resources: 512Mi-1Gi RAM, 250-500m CPU

Shard 2:
  Replica Set: rs-shard2
  Members: 2 (Primary + Secondary)
  Storage: 2-5GB per replica
  Resources: 512Mi-1Gi RAM, 250-500m CPU
```

**Why 2 replicas per shard?** Minimum for automatic failover. Primary handles writes, secondary provides HA.

#### 3. Mongos Routers (1-2 replicas)

**Purpose**: Query routing and load balancing

```yaml
Production: 2 replicas (load balanced)
Test: 1 replica (simplified)
Resources: 256-512Mi RAM, 100-250m CPU
```

**Why mongos?** Applications connect here. Mongos routes queries to correct shards transparently.

### Data Flow

```
Application → Mongos Router → Appropriate Shard → Replica Set Primary → Replicate to Secondary
```

### Sharding Strategy

**Hash-based Sharding (users collection):**

```javascript
sh.shardCollection("myapp.users", { _id: "hashed" });
```

- Distributes users evenly across shards
- Good for balanced write distribution

**Range-based Sharding (items collection):**

```javascript
sh.shardCollection("myapp.items", { userId: 1, _id: 1 });
```

- Co-locates user data on same shard
- Efficient for user-specific queries

---

## Deployment Steps

### Automated Deployment (Recommended)

```powershell
# Deploy everything
.\scripts\deploy-mongodb.ps1 -Environment all

# Options:
#   -Environment: prod, test, or all
#   -SkipInit: Skip initialization job
#   -WaitForReady: Wait for all pods (default: true)
#   -TimeoutSeconds: Timeout for waiting (default: 600)
```

### Manual Deployment (Step by Step)

#### Step 1: Deploy Production

```powershell
# Create namespace and configuration
kubectl apply -f kubernetes/mongodb/prod/00-namespace-secret-config.yaml

# Deploy StatefulSets and Services
kubectl apply -f kubernetes/mongodb/prod/01-statefulsets-services.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=mongo-config -n mongodb-prod --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard1 -n mongodb-prod --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard2 -n mongodb-prod --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongos -n mongodb-prod --timeout=300s

# Initialize cluster
kubectl apply -f kubernetes/mongodb/prod/02-init-job.yaml

# Wait for initialization to complete
kubectl wait --for=condition=complete job/mongodb-init -n mongodb-prod --timeout=300s

# Check initialization logs
kubectl logs -n mongodb-prod job/mongodb-init
```

#### Step 2: Deploy Test

```powershell
# Repeat for test environment
kubectl apply -f kubernetes/mongodb/test/00-namespace-secret-config.yaml
kubectl apply -f kubernetes/mongodb/test/01-statefulsets-services.yaml

# Wait and initialize
kubectl wait --for=condition=ready pod -l app=mongo-config -n mongodb-test --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard1 -n mongodb-test --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongo-shard2 -n mongodb-test --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongos -n mongodb-test --timeout=300s

kubectl apply -f kubernetes/mongodb/test/02-init-job.yaml
kubectl wait --for=condition=complete job/mongodb-init -n mongodb-test --timeout=300s
```

#### Step 3: Verify Deployment

```powershell
# Check all pods
kubectl get pods -n mongodb-prod
kubectl get pods -n mongodb-test

# Verify cluster status
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "sh.status()"
kubectl exec -it mongos-0 -n mongodb-test -- mongosh --eval "sh.status()"
```

---

## Configuration Details

### Namespace Configuration

**Purpose**: Isolate production and test environments

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mongodb-prod
  labels:
    environment: production
```

### Secrets

**Important**: Change default passwords in production!

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
stringData:
  MONGO_INITDB_ROOT_USERNAME: admin
  MONGO_INITDB_ROOT_PASSWORD: <CHANGE_ME>
  MONGO_REPLICA_SET_KEY: <CHANGE_ME>
```

**To update secrets:**

```powershell
kubectl edit secret mongodb-secret -n mongodb-prod
```

### StatefulSet Configuration

**Why StatefulSets?**

- Stable pod identities (mongo-shard1-0, mongo-shard1-1)
- Ordered deployment and scaling
- Persistent storage association

**Key settings:**

```yaml
serviceName: mongo-shard1-svc # Headless service for DNS
replicas: 2 # Number of replicas
volumeClaimTemplates: # Persistent storage
  storage: 5Gi # Per-pod storage
```

### Service Configuration

**Headless Services** (ClusterIP: None):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo-shard1-svc
spec:
  clusterIP: None # Headless
  selector:
    app: mongo-shard1
```

**Purpose**: Provides stable DNS names for each pod:

- `mongo-shard1-0.mongo-shard1-svc.mongodb-prod.svc.cluster.local`
- `mongo-shard1-1.mongo-shard1-svc.mongodb-prod.svc.cluster.local`

**Mongos Service** (ClusterIP):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongos-svc
spec:
  type: ClusterIP
  selector:
    app: mongos
```

**Purpose**: Single endpoint for applications to connect

---

## Schema Management

### Migration Framework

Located in `kubernetes/mongodb/migrations/`

#### Creating a Migration

**Template:**

```javascript
// migrations/002-add-profile-fields.js
db = db.getSiblingDB("myapp");

function up() {
  print("Adding profile fields to users...");

  // Add new fields
  db.users.updateMany(
    { profile: { $exists: false } },
    {
      $set: {
        profile: { bio: "", avatar: null, social: {} },
        settings: { theme: "light", notifications: true },
      },
    }
  );

  // Create index
  db.users.createIndex({ "profile.bio": "text" });

  // Track migration
  db.migrations.insertOne({
    migration: "002-add-profile-fields",
    description: "Add user profile and settings",
    executed_at: new Date(),
    status: "completed",
  });

  print("Migration 002 completed");
}

function down() {
  print("Removing profile fields...");

  db.users.updateMany({}, { $unset: { profile: 1, settings: 1 } });

  db.users.dropIndex("profile.bio_text");

  db.migrations.deleteOne({ migration: "002-add-profile-fields" });

  print("Migration 002 reverted");
}

up();
```

#### Applying Migrations

```powershell
# Test environment first
kubectl exec -it mongos-0 -n mongodb-test -- mongosh < kubernetes/mongodb/migrations/002-add-profile-fields.js

# Verify
kubectl exec -it mongos-0 -n mongodb-test -- mongosh --eval "use myapp; db.migrations.find().pretty()"

# If successful, apply to production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < kubernetes/mongodb/migrations/002-add-profile-fields.js
```

#### Checking Migration Status

```javascript
// Connect to mongos
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh

// Check applied migrations
use myapp
db.migrations.find().sort({ executed_at: 1 })

// Output:
{
  _id: ObjectId("..."),
  migration: "001-initial-schema",
  description: "Initial schema with users, items, orders",
  executed_at: ISODate("2025-01-15T10:30:00Z"),
  status: "completed",
  version: "1.0.0"
}
```

#### Rolling Back Migrations

```javascript
// Load migration file and run down() function
load("migrations/002-add-profile-fields.js");
down();
```

---

## Test Database Refresh

### Purpose

Sync test database with production data while anonymizing PII for GDPR compliance.

### Process Flow

```
1. Backup Production
   └─ mongodump via port-forward

2. Anonymize Data
   ├─ Transform usernames
   ├─ Transform emails
   ├─ Transform names, phones, addresses
   └─ Preserve IDs, relationships, hashes

3. Clear Test Database
   └─ Drop existing test data

4. Restore Anonymized Data
   └─ mongorestore to test

5. Verify Integrity
   └─ Check document counts and sample data
```

### Usage

```powershell
# Preview changes (recommended first)
.\scripts\refresh-test-db.ps1 -DryRun

# Perform refresh
.\scripts\refresh-test-db.ps1

# Custom database and backup location
.\scripts\refresh-test-db.ps1 -Database "myapp" -BackupDir "./backup-custom"
```

### Anonymization Strategy

**Anonymized Fields:**

```
username: john_smith → testuser_5a3b2c1d
email: john@company.com → testuser_5a3b2c1d@example.com
firstName: John → TestFirst_42
lastName: Smith → TestLast_42
phone: +1-555-1234 → 555-01234
address: Full anonymization to test data
```

**Preserved Fields:**

```
_id: Preserved (maintains relationships)
passwordHash: Preserved (for auth testing)
createdAt: Preserved (for date logic)
userId references: Preserved (foreign keys)
```

### Frequency Recommendations

- **Daily**: For active development
- **Weekly**: For stable development
- **On demand**: Before major testing
- **After migrations**: To test with new schema

---

## Monitoring & Maintenance

### Health Checks

```powershell
# Pod health
kubectl get pods -n mongodb-prod -w

# Replica set status
kubectl exec -it mongo-config-0 -n mongodb-prod -- mongosh --eval "rs.status()"
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- mongosh --eval "rs.status()"
kubectl exec -it mongo-shard2-0 -n mongodb-prod -- mongosh --eval "rs.status()"

# Shard status
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "sh.status()"
```

### Resource Monitoring

```powershell
# Pod resource usage
kubectl top pods -n mongodb-prod

# Node resource usage
kubectl top nodes

# Storage usage
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- df -h /data/db
```

### Query Performance

```javascript
// Enable profiling
use myapp
db.setProfilingLevel(2, { slowms: 100 })

// View slow queries
db.system.profile.find({ millis: { $gt: 100 } }).sort({ ts: -1 }).limit(10).pretty()

// Check current operations
db.currentOp()

// Kill slow query
db.killOp(operationId)
```

### Index Management

```javascript
// List indexes
db.users.getIndexes();

// Create index
db.users.createIndex({ email: 1 }, { unique: true, name: "email_unique" });

// Drop index
db.users.dropIndex("email_unique");

// Rebuild indexes
db.users.reIndex();
```

---

## Performance Tuning

### Connection Pooling

```javascript
// Application connection string
mongodb://mongos-svc.mongodb-prod.svc.cluster.local:27017/myapp?maxPoolSize=50&minPoolSize=10
```

### Read Preferences

```javascript
// Read from secondaries for analytics
db.users.find().readPref("secondary");

// Read from nearest for low latency
db.users.find().readPref("nearest");
```

### Write Concerns

```javascript
// Wait for majority (safer, slower)
db.users.insert({...}, { writeConcern: { w: 'majority' } })

// Fire and forget (faster, risky)
db.users.insert({...}, { writeConcern: { w: 0 } })
```

### Shard Key Selection

**Good shard keys:**

- High cardinality (many unique values)
- Even distribution
- Frequently queried

**Bad shard keys:**

- Monotonically increasing (\_id, timestamp)
- Low cardinality (boolean, status)
- Rarely queried

**Examples:**

```javascript
// Good: Hashed _id
sh.shardCollection("myapp.users", { _id: "hashed" });

// Good: Compound key for co-location
sh.shardCollection("myapp.orders", { customerId: 1, orderDate: 1 });

// Bad: Timestamp (creates hot spot)
sh.shardCollection("myapp.logs", { timestamp: 1 });
```

---

## Backup & Recovery

### Backup Production Database

```powershell
# Port forward mongos
kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017

# Backup all databases
mongodump --host localhost:27017 --out ./backup-$(Get-Date -Format 'yyyy-MM-dd')

# Backup specific database
mongodump --host localhost:27017 --db myapp --out ./backup-myapp
```

### Restore from Backup

```powershell
# Port forward mongos
kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017

# Restore database
mongorestore --host localhost:27017 --db myapp --dir ./backup-myapp/myapp

# Restore with drop existing
mongorestore --host localhost:27017 --db myapp --dir ./backup-myapp/myapp --drop
```

### Automated Backups

**CronJob for backups:**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
  namespace: mongodb-prod
spec:
  schedule: "0 2 * * *" # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: mongo:7.0
              command:
                - /bin/bash
                - -c
                - |
                  mongodump --host mongos-svc.mongodb-prod.svc.cluster.local:27017 \
                    --out /backup/$(date +%Y-%m-%d) \
                    --gzip
              volumeMounts:
                - name: backup-storage
                  mountPath: /backup
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: mongodb-backup-pvc
          restartPolicy: OnFailure
```

---

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

**Symptoms:**

```
NAME              READY   STATUS    RESTARTS
mongo-config-0    0/1     Pending   0
```

**Diagnosis:**

```powershell
kubectl describe pod mongo-config-0 -n mongodb-prod
kubectl get events -n mongodb-prod --sort-by='.lastTimestamp'
```

**Common causes:**

- Insufficient resources (CPU/memory)
- No storage class available
- PVC provisioning failed

**Solutions:**

```powershell
# Check resource availability
kubectl top nodes

# Check storage class
kubectl get storageclass

# Manually provision PV if needed
```

#### 2. Replica Set Won't Initialize

**Symptoms:**
Init job fails or hangs

**Diagnosis:**

```powershell
kubectl logs -n mongodb-prod job/mongodb-init
```

**Solutions:**

```powershell
# Delete and recreate init job
kubectl delete job mongodb-init -n mongodb-prod
kubectl apply -f kubernetes/mongodb/prod/02-init-job.yaml

# Manually initialize if needed
kubectl exec -it mongo-config-0 -n mongodb-prod -- mongosh
rs.initiate(...)
```

#### 3. Cannot Connect to MongoDB

**Diagnosis:**

```powershell
# Test from within cluster
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "db.adminCommand('ping')"

# Check services
kubectl get services -n mongodb-prod

# Check endpoints
kubectl get endpoints -n mongodb-prod
```

**Solutions:**

```powershell
# Restart mongos
kubectl rollout restart deployment mongos -n mongodb-prod

# Check config server connectivity
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "sh.status()"
```

#### 4. Split Brain / Replica Set Issues

**Symptoms:**
Multiple primaries or no primary

**Diagnosis:**

```javascript
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- mongosh
rs.status()
```

**Solutions:**

```javascript
// Force reconfigure (use carefully!)
rs.reconfig(rs.conf(), { force: true });

// Stepdown current primary
rs.stepDown();

// Remove problematic member
rs.remove("mongo-shard1-1.mongo-shard1-svc:27017");
rs.add("mongo-shard1-1.mongo-shard1-svc:27017");
```

#### 5. Disk Full

**Symptoms:**
Write errors, pod eviction

**Diagnosis:**

```powershell
kubectl exec -it mongo-shard1-0 -n mongodb-prod -- df -h
```

**Solutions:**

```powershell
# Increase PVC size (if storage class supports it)
kubectl edit pvc mongo-data-mongo-shard1-0 -n mongodb-prod

# Compact database
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "db.runCommand({compact: 'users'})"

# Remove old data
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "use myapp; db.logs.deleteMany({createdAt: {\$lt: new Date('2024-01-01')}})"
```

### Getting Help

```powershell
# View all resources
kubectl get all -n mongodb-prod

# Describe problematic resource
kubectl describe pod <pod-name> -n mongodb-prod

# View logs
kubectl logs <pod-name> -n mongodb-prod

# Interactive debugging
kubectl exec -it <pod-name> -n mongodb-prod -- /bin/bash

# Port forward for local debugging
kubectl port-forward <pod-name> -n mongodb-prod 27017:27017
```

---

## Best Practices

### Security

1. **Change default passwords** in secrets
2. **Enable authentication** (already configured)
3. **Use network policies** to restrict access
4. **Encrypt data at rest** (storage class dependent)
5. **Use TLS** for production (advanced configuration)

### Scalability

1. **Choose appropriate shard keys**
2. **Monitor shard distribution** regularly
3. **Add shards before capacity issues**
4. **Use connection pooling** in applications
5. **Index frequently queried fields**

### Reliability

1. **Test failover scenarios** regularly
2. **Backup before migrations**
3. **Monitor replica lag**
4. **Set up alerts** for pod failures
5. **Test disaster recovery** procedures

### Operations

1. **Test in test environment first**
2. **Document all manual changes**
3. **Use version control** for migrations
4. **Automate repetitive tasks**
5. **Monitor resource usage** trends

---

## Additional Resources

- [MongoDB Documentation](https://docs.mongodb.com/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [MongoDB Sharding Guide](https://docs.mongodb.com/manual/sharding/)
- [MongoDB Replication](https://docs.mongodb.com/manual/replication/)
- [Lab 4 Tutorial](https://quentin.lurkin.xyz/courses/scalable/lab4/)

---

**Questions?** Refer to the main `README.md` or open an issue in the repository.
