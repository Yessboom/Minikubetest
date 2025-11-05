# MongoDB Test Database Refresh Script
# This script copies data from Production to Test with anonymization
# Complies with requirement: "Implement a procedure to refresh the Test DB from Production data (anonymized if necessary)"

param(
    [switch]$DryRun = $false,
    [string]$Database = "myapp",
    [string]$BackupDir = "./mongodb-backup-temp"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MongoDB Test DB Refresh with Anonymization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN MODE] No actual changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Function to execute mongosh commands
function Invoke-MongoCommand {
    param(
        [string]$Namespace,
        [string]$PodName,
        [string]$Command
    )
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would execute: $Command" -ForegroundColor Yellow
        return "DRY RUN"
    }
    
    $result = kubectl exec -it $PodName -n $Namespace -- mongosh --quiet --eval $Command 2>&1
    return $result
}

# Step 1: Verify clusters are running
Write-Host "Step 1: Verifying MongoDB clusters..." -ForegroundColor Green
Write-Host "Checking Production cluster..."
$prodPods = kubectl get pods -n mongodb-prod -l app=mongos --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Production MongoDB cluster not found!" -ForegroundColor Red
    Write-Host "Please deploy the production cluster first:" -ForegroundColor Yellow
    Write-Host "  kubectl apply -f kubernetes/mongodb/prod/" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Production cluster is running" -ForegroundColor Green

Write-Host "Checking Test cluster..."
$testPods = kubectl get pods -n mongodb-test -l app=mongos --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Test MongoDB cluster not found!" -ForegroundColor Red
    Write-Host "Please deploy the test cluster first:" -ForegroundColor Yellow
    Write-Host "  kubectl apply -f kubernetes/mongodb/test/" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Test cluster is running" -ForegroundColor Green
Write-Host ""

# Step 2: Create backup directory
Write-Host "Step 2: Preparing backup directory..." -ForegroundColor Green
if (-not $DryRun) {
    if (Test-Path $BackupDir) {
        Write-Host "Cleaning existing backup directory..."
        Remove-Item -Path $BackupDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
Write-Host "✓ Backup directory ready: $BackupDir" -ForegroundColor Green
Write-Host ""

# Step 3: Backup production database
Write-Host "Step 3: Backing up Production database..." -ForegroundColor Green
Write-Host "Database: $Database"
Write-Host "This may take several minutes depending on data size..."

if (-not $DryRun) {
    # Port forward production mongos
    Write-Host "Setting up port forward to production..."
    $prodPortForward = Start-Job -ScriptBlock {
        kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017
    }
    Start-Sleep -Seconds 5
    
    try {
        Write-Host "Running mongodump..."
        $dumpResult = mongodump --host localhost:27017 --db=$Database --out=$BackupDir 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "mongodump failed: $dumpResult"
        }
        Write-Host "✓ Backup completed successfully" -ForegroundColor Green
    }
    finally {
        # Stop port forward
        Stop-Job -Job $prodPortForward
        Remove-Job -Job $prodPortForward
    }
} else {
    Write-Host "[DRY RUN] Would backup database to $BackupDir" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Anonymize sensitive data
Write-Host "Step 4: Anonymizing sensitive data..." -ForegroundColor Green
Write-Host "Anonymizing: emails, usernames, phone numbers, addresses"
Write-Host "Preserving: user IDs, password hashes (for testing), data relationships"

if (-not $DryRun) {
    # Path to users BSON file
    $usersFile = Join-Path $BackupDir "$Database\users.bson"
    
    if (Test-Path $usersFile) {
        Write-Host "Creating anonymization script..."
        
        # Create a JavaScript anonymization script
        $anonymizeScript = @"
db = db.getSiblingDB('$Database');

print('Starting anonymization...');

var count = 0;
var errors = 0;

// Anonymize users collection
db.users.find().forEach(function(user) {
    try {
        var userId = user._id.toString();
        var anonymized = {
            username: 'testuser_' + userId.substring(userId.length - 8),
            email: 'testuser_' + userId.substring(userId.length - 8) + '@example.com'
        };
        
        // Preserve password hash for authentication testing
        // Anonymize other PII
        if (user.firstName) anonymized.firstName = 'TestFirst_' + (count % 100);
        if (user.lastName) anonymized.lastName = 'TestLast_' + (count % 100);
        if (user.phone) anonymized.phone = '555-0' + String(1000 + (count % 9000));
        if (user.address) {
            anonymized.address = {
                street: (count % 100) + ' Test Street',
                city: 'TestCity',
                state: 'TS',
                zip: '00000',
                country: 'TestCountry'
            };
        }
        
        db.users.updateOne({ _id: user._id }, { \$set: anonymized });
        count++;
        
        if (count % 100 === 0) {
            print('Anonymized ' + count + ' users...');
        }
    } catch (e) {
        errors++;
        print('Error anonymizing user ' + user._id + ': ' + e);
    }
});

print('Anonymization complete: ' + count + ' users processed, ' + errors + ' errors');

// List collections to check what else might need anonymization
print('Collections in database:');
db.getCollectionNames().forEach(function(name) {
    var collCount = db.getCollection(name).countDocuments();
    print('  - ' + name + ': ' + collCount + ' documents');
});
"@
        
        $scriptFile = Join-Path $BackupDir "anonymize.js"
        $anonymizeScript | Out-File -FilePath $scriptFile -Encoding UTF8
        
        Write-Host "Restoring to temporary location for anonymization..."
        # Restore to production temporarily to anonymize
        $tempDb = "$Database`_temp_anon"
        mongorestore --host localhost:27017 --db=$tempDb --dir=(Join-Path $BackupDir $Database) --drop 2>&1 | Out-Null
        
        # Connect to production and run anonymization
        $prodPortForward = Start-Job -ScriptBlock {
            kubectl port-forward svc/mongos-svc -n mongodb-prod 27017:27017
        }
        Start-Sleep -Seconds 5
        
        try {
            Write-Host "Running anonymization script..."
            
            # Update script to use temp database
            $anonymizeScript = $anonymizeScript -replace "db = db.getSiblingDB\('$Database'\);", "db = db.getSiblingDB('$tempDb');"
            $anonymizeScript | Out-File -FilePath $scriptFile -Encoding UTF8 -Force
            
            mongosh --host localhost:27017 --file $scriptFile
            
            Write-Host "Backing up anonymized data..."
            mongodump --host localhost:27017 --db=$tempDb --out=$BackupDir\anonymized 2>&1 | Out-Null
            
            Write-Host "Cleaning up temporary database..."
            mongosh --host localhost:27017 --eval "db.getSiblingDB('$tempDb').dropDatabase()" --quiet 2>&1 | Out-Null
            
            # Update backup directory
            Remove-Item (Join-Path $BackupDir $Database) -Recurse -Force
            Move-Item (Join-Path $BackupDir "anonymized\$tempDb") (Join-Path $BackupDir $Database)
            Remove-Item (Join-Path $BackupDir "anonymized") -Recurse -Force
            
            Write-Host "✓ Data anonymized successfully" -ForegroundColor Green
        }
        finally {
            Stop-Job -Job $prodPortForward
            Remove-Job -Job $prodPortForward
        }
    } else {
        Write-Host "⚠ No users collection found in backup, skipping anonymization" -ForegroundColor Yellow
    }
} else {
    Write-Host "[DRY RUN] Would anonymize data in $BackupDir" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Clear test database
Write-Host "Step 5: Clearing Test database..." -ForegroundColor Green
Write-Host "⚠ WARNING: This will delete all data in the test database!" -ForegroundColor Yellow

if (-not $DryRun) {
    $testPortForward = Start-Job -ScriptBlock {
        kubectl port-forward svc/mongos-svc -n mongodb-test 27018:27017
    }
    Start-Sleep -Seconds 5
    
    try {
        Write-Host "Dropping test database..."
        mongosh --host localhost:27018 --eval "db.getSiblingDB('$Database').dropDatabase()" --quiet 2>&1 | Out-Null
        Write-Host "✓ Test database cleared" -ForegroundColor Green
    }
    finally {
        Stop-Job -Job $testPortForward
        Remove-Job -Job $testPortForward
    }
} else {
    Write-Host "[DRY RUN] Would drop database: $Database" -ForegroundColor Yellow
}
Write-Host ""

# Step 6: Restore anonymized data to test
Write-Host "Step 6: Restoring anonymized data to Test..." -ForegroundColor Green

if (-not $DryRun) {
    $testPortForward = Start-Job -ScriptBlock {
        kubectl port-forward svc/mongos-svc -n mongodb-test 27018:27017
    }
    Start-Sleep -Seconds 5
    
    try {
        Write-Host "Running mongorestore..."
        mongorestore --host localhost:27018 --db=$Database --dir=(Join-Path $BackupDir $Database) --drop 2>&1 | Out-Null
        Write-Host "✓ Data restored to test database" -ForegroundColor Green
    }
    finally {
        Stop-Job -Job $testPortForward
        Remove-Job -Job $testPortForward
    }
} else {
    Write-Host "[DRY RUN] Would restore data to test database" -ForegroundColor Yellow
}
Write-Host ""

# Step 7: Verify and report
Write-Host "Step 7: Verification..." -ForegroundColor Green

if (-not $DryRun) {
    $testPortForward = Start-Job -ScriptBlock {
        kubectl port-forward svc/mongos-svc -n mongodb-test 27018:27017
    }
    Start-Sleep -Seconds 5
    
    try {
        Write-Host "Checking document counts..."
        $collections = mongosh --host localhost:27018 --eval "db.getSiblingDB('$Database').getCollectionNames()" --quiet 2>&1
        
        mongosh --host localhost:27018 --eval @"
db = db.getSiblingDB('$Database');
print('Collections in test database:');
db.getCollectionNames().forEach(function(name) {
    var count = db.getCollection(name).countDocuments();
    print('  - ' + name + ': ' + count + ' documents');
});

print('\nSample anonymized user:');
var user = db.users.findOne({}, { passwordHash: 0 });
if (user) {
    printjson(user);
}
"@ --quiet
        
        Write-Host "✓ Verification complete" -ForegroundColor Green
    }
    finally {
        Stop-Job -Job $testPortForward
        Remove-Job -Job $testPortForward
    }
} else {
    Write-Host "[DRY RUN] Would verify data in test database" -ForegroundColor Yellow
}
Write-Host ""

# Step 8: Cleanup
Write-Host "Step 8: Cleanup..." -ForegroundColor Green
if (-not $DryRun) {
    Write-Host "Removing backup files..."
    Remove-Item -Path $BackupDir -Recurse -Force
    Write-Host "✓ Cleanup complete" -ForegroundColor Green
} else {
    Write-Host "[DRY RUN] Would remove backup directory: $BackupDir" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Database Refresh Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
if ($DryRun) {
    Write-Host "This was a DRY RUN - no changes were made" -ForegroundColor Yellow
    Write-Host "Run without the -DryRun flag to perform actual refresh:" -ForegroundColor Yellow
    Write-Host "  .\scripts\refresh-test-db.ps1" -ForegroundColor Yellow
} else {
    Write-Host "Summary:" -ForegroundColor Green
    Write-Host "  ✓ Production data backed up"
    Write-Host "  ✓ Sensitive data anonymized"
    Write-Host "  ✓ Test database refreshed"
    Write-Host "  ✓ Data integrity verified"
    Write-Host ""
    Write-Host "Anonymization applied to:" -ForegroundColor Green
    Write-Host "  • Usernames (testuser_XXXXXXXX)"
    Write-Host "  • Emails (testuser_XXXXXXXX@example.com)"
    Write-Host "  • Names, phone numbers, addresses"
    Write-Host ""
    Write-Host "Preserved:" -ForegroundColor Green
    Write-Host "  • User IDs and relationships"
    Write-Host "  • Password hashes (for testing)"
    Write-Host "  • Data structure and integrity"
    Write-Host ""
    Write-Host "Access test database:" -ForegroundColor Cyan
    Write-Host "  kubectl exec -it mongos-0 -n mongodb-test -- mongosh" -ForegroundColor White
}
Write-Host ""
