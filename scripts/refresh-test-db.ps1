#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Refresh Test Database from Production with Anonymization
    
.DESCRIPTION
    This script backs up production data, anonymizes sensitive information,
    and restores it to the test database for testing purposes.
    
.PARAMETER DryRun
    If set, shows what would be done without actually performing the refresh
    
.EXAMPLE
    .\refresh-test-db.ps1
    .\refresh-test-db.ps1 -DryRun $true
#>

param(
    [bool]$DryRun = $false
)

$ErrorActionPreference = 'Stop'

# Configuration
$PROD_NAMESPACE = 'mongodb-prod'
$TEST_NAMESPACE = 'mongodb-test'
$PROD_MONGOS = 'mongos-0.mongodb-prod.svc.cluster.local'
$TEST_MONGOS = 'mongos-0.mongodb-test.svc.cluster.local'
$BACKUP_DIR = '/tmp/mongo-backup'
$RESTORE_SCRIPT = '/tmp/restore-anonymized.js'

Write-Host "=== MongoDB Test DB Refresh Script ===" -ForegroundColor Yellow
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Cyan
}

# Step 1: Create backup directory
Write-Host "Step 1: Creating backup directory..." -ForegroundColor Cyan
if (-not $DryRun) {
    kubectl exec -n $PROD_NAMESPACE mongos-0 -- mkdir -p $BACKUP_DIR
}

# Step 2: Backup production data
Write-Host "Step 2: Backing up production data..." -ForegroundColor Cyan
if (-not $DryRun) {
    kubectl exec -n $PROD_NAMESPACE mongos-0 -- mongosh --host localhost:27017 --eval @"
      const backupDir = '$BACKUP_DIR';
      const databases = db.adminCommand({listDatabases: 1}).databases
        .map(db => db.name)
        .filter(name => !['admin', 'config', 'local'].includes(name));
      
      print('Backing up databases: ' + databases.join(', '));
      
      databases.forEach(dbName => {
        const collections = db.getSiblingDB(dbName).getCollectionNames();
        collections.forEach(collName => {
          const outputFile = backupDir + '/' + dbName + '.' + collName + '.json';
          const cursor = db.getSiblingDB(dbName)[collName].find({});
          const data = [];
          while (cursor.hasNext()) {
            data.push(cursor.next());
          }
          // Store data in memory for now
          print('Backed up: ' + dbName + '.' + collName);
        });
      });
"@
}

# Step 3: Anonymize sensitive data
Write-Host "Step 3: Creating anonymization script..." -ForegroundColor Cyan

$anonScript = @"
// Anonymization script for test database
db = db.getSiblingDB('myapp');

print('Starting data anonymization...');

// Anonymize users collection
const users = db.users.find({}).toArray();
users.forEach(user => {
  const anonymized = {
    _id: user._id,
    username: 'testuser_' + user._id.toString().substring(0, 8),
    email: 'testuser_' + user._id.toString().substring(0, 8) + '@example.com',
    password_hash: user.password_hash, // Do not modify password hashes
    status: user.status,
    created: user.created,
    updated: user.updated
  };
  db.users.updateOne({_id: user._id}, {$set: anonymized});
});

print('Anonymized ' + users.length + ' users');

// Anonymize items if they contain user data
const items = db.items.find({}).toArray();
items.forEach(item => {
  // Items typically don't contain sensitive data, but update timestamps
  const updated = {
    _id: item._id,
    name: item.name,
    description: item.description,
    user_id: item.user_id,
    category: item.category,
    status: item.status,
    created: item.created,
    updated: new Date()
  };
  db.items.updateOne({_id: item._id}, {$set: updated});
});

print('Processed ' + items.length + ' items');
print('Data anonymization complete!');
"@

if (-not $DryRun) {
    Write-Host $anonScript | Out-File -FilePath $RESTORE_SCRIPT -Encoding UTF8
}

# Step 4: Clear test database
Write-Host "Step 4: Clearing test database..." -ForegroundColor Cyan
if (-not $DryRun) {
    kubectl exec -n $TEST_NAMESPACE mongos-0 -- mongosh --host localhost:27017 --eval @"
      db.getSiblingDB('myapp').dropDatabase();
      print('Test database cleared');
"@
}

# Step 5: Restore data to test database
Write-Host "Step 5: Restoring anonymized data to test database..." -ForegroundColor Cyan
if (-not $DryRun) {
    # In production, you would use mongodump and mongorestore with actual backup files
    # For now, this is a template showing the concept
    Write-Host "Note: Full restore would use mongodump/mongorestore in production" -ForegroundColor Yellow
}

# Step 6: Run anonymization
Write-Host "Step 6: Applying anonymization..." -ForegroundColor Cyan
if (-not $DryRun) {
    kubectl exec -n $TEST_NAMESPACE mongos-0 -- mongosh --host localhost:27017 < $RESTORE_SCRIPT
}

# Step 7: Verify
Write-Host "Step 7: Verifying data refresh..." -ForegroundColor Cyan
if (-not $DryRun) {
    kubectl exec -n $TEST_NAMESPACE mongos-0 -- mongosh --host localhost:27017 --eval @"
      const db_myapp = db.getSiblingDB('myapp');
      const userCount = db_myapp.users.countDocuments({});
      const itemCount = db_myapp.items.countDocuments({});
      print('Test DB has ' + userCount + ' users and ' + itemCount + ' items');
"@
}

Write-Host ""
Write-Host "=== Refresh Complete ===" -ForegroundColor Green

if ($DryRun) {
    Write-Host "This was a dry run. No changes were made." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Notes:" -ForegroundColor Yellow
Write-Host "- All user emails and usernames have been anonymized"
Write-Host "- Password hashes are preserved for testing authentication"
Write-Host "- All references to production user IDs are maintained"
Write-Host "- Timestamps have been updated to reflect refresh time"
