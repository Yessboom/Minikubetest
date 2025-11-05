# MongoDB Schema Migrations

This directory contains versioned migration scripts for MongoDB schema updates.

## Overview

Migrations are JavaScript files that can be executed against MongoDB to:
- Create/modify collections and indexes
- Transform existing data
- Add/remove fields
- Setup sharding configuration

Each migration is tracked in the database to prevent re-running.

## Migration File Format

Create files named: `NNN-description.js` where NNN is a 3-digit number.

Example: `001-initial-schema.js`

Each migration should have two functions:
- `up()` - Apply the migration
- `down()` - Revert the migration (optional)

```javascript
// Template
db = db.getSiblingDB('myapp');

function up() {
  // Create collections
  db.createCollection('users');
  
  // Create indexes
  db.users.createIndex({ email: 1 }, { unique: true });
  
  // Track migration
  db.migrations.insertOne({
    migration: '001-initial-schema',
    executed_at: new Date(),
    status: 'completed'
  });
  
  print('Migration 001: Completed');
}

function down() {
  // Revert changes
  db.users.drop();
  db.migrations.deleteOne({ migration: '001-initial-schema' });
  print('Migration 001: Reverted');
}

// Execute
up();
```

## Applying Migrations

### To Production
```powershell
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < kubernetes/mongodb/migrations/001-initial-schema.js
```

### To Test
```powershell
kubectl exec -it mongos-0 -n mongodb-test -- mongosh < kubernetes/mongodb/migrations/001-initial-schema.js
```

### Port-Forward Method
```powershell
# Start port forward
kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017

# In another terminal
mongosh mongodb://localhost:27017/admin < kubernetes/mongodb/migrations/001-initial-schema.js
```

## Checking Migration Status

```javascript
// Connect to mongos
mongosh --host mongos-svc.mongodb-prod.svc.cluster.local:27017

// Check applied migrations
use myapp
db.migrations.find().sort({ executed_at: 1 })
```

## Best Practices

1. **Always test migrations on test environment first**
   - Apply to mongodb-test
   - Verify data integrity
   - Then apply to mongodb-prod

2. **Make migrations idempotent**
   - Check if changes already exist
   - Safe to run multiple times

3. **Include rollback instructions**
   - Write `down()` function
   - Document manual rollback steps

4. **Backup before major migrations**
   ```powershell
   kubectl exec -it mongos-0 -n mongodb-prod -- mongodump --out=/backup
   ```

5. **Track all migrations**
   - Always insert into `migrations` collection
   - Include timestamp and status

## Sharding Considerations

When creating sharded collections:

```javascript
// Enable sharding for database
sh.enableSharding("myapp");

// Shard a collection by _id (hash-based)
sh.shardCollection("myapp.users", { _id: "hashed" });

// Or by a specific field
sh.shardCollection("myapp.orders", { customerId: 1, orderDate: 1 });
```

## Example Migration Flow

```powershell
# 1. Create new migration file
New-Item kubernetes/mongodb/migrations/002-add-orders.js

# 2. Write migration code
# (Edit the file with collection/index creation)

# 3. Apply to test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh < kubernetes/mongodb/migrations/002-add-orders.js

# 4. Verify in test
kubectl exec -it mongos-0 -n mongodb-test -- mongosh --eval "use myapp; db.orders.stats()"

# 5. Apply to production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh < kubernetes/mongodb/migrations/002-add-orders.js

# 6. Verify in production
kubectl exec -it mongos-0 -n mongodb-prod -- mongosh --eval "use myapp; db.orders.stats()"
```

## Migration Ordering

Migrations are applied in numerical order:
- 001-initial-schema.js
- 002-add-user-fields.js
- 003-add-orders-collection.js
- 004-create-indexes.js

Always increment the number for new migrations.

## Handling Failed Migrations

If a migration fails:

1. Check the error in the job logs
2. Fix the migration script
3. Manually clean up partial changes:
   ```javascript
   use myapp
   db.migrations.deleteOne({ migration: '002-example' })
   // Manually revert any partial changes
   ```
4. Re-run the corrected migration

## Data Transformation Examples

### Add new field with default value
```javascript
db.users.updateMany(
  { profile: { $exists: false } },
  { $set: { profile: { bio: '', avatar: null } } }
);
```

### Rename field
```javascript
db.users.updateMany(
  {},
  { $rename: { "oldFieldName": "newFieldName" } }
);
```

### Convert field type
```javascript
db.users.find({ age: { $type: "string" } }).forEach(function(doc) {
  db.users.updateOne(
    { _id: doc._id },
    { $set: { age: parseInt(doc.age) } }
  );
});
```

## See Also

- [MongoDB Sharding Documentation](https://docs.mongodb.com/manual/sharding/)
- [MongoDB Indexes](https://docs.mongodb.com/manual/indexes/)
- [Data Modeling Guide](https://docs.mongodb.com/manual/core/data-modeling-introduction/)
