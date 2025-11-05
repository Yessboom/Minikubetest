# Simple MongoDB Test DB Refresh Script
# Copies data from Production to Test with anonymization

param(
    [string]$Database = "myapp"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MongoDB Test DB Refresh (Simple Version)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get pod names
Write-Host "Getting pod names..." -ForegroundColor Green
$prodPod = kubectl get pods -n mongodb-prod -l app=mongos -o jsonpath="{.items[0].metadata.name}"
$testPod = kubectl get pods -n mongodb-test -l app=mongos -o jsonpath="{.items[0].metadata.name}"

Write-Host "Production pod: $prodPod" -ForegroundColor White
Write-Host "Test pod: $testPod" -ForegroundColor White
Write-Host ""

# Step 1: Export data from production using a script file
Write-Host "Step 1: Exporting data from Production..." -ForegroundColor Green

$exportJsContent = "db = db.getSiblingDB('$Database');`nvar users = db.users.find().toArray();`nprintjson(users);"
$exportJs = ".\temp-export.js"
$exportJsContent | Out-File -FilePath $exportJs -Encoding UTF8

kubectl cp $exportJs "mongodb-prod/$prodPod":/tmp/export.js
$exportData = kubectl exec -i $prodPod -n mongodb-prod -- mongosh /tmp/export.js --quiet

$tempExportFile = ".\temp-export.json"
$exportData | Out-File -FilePath $tempExportFile -Encoding UTF8

Remove-Item $exportJs -Force

Write-Host "✓ Exported data from production" -ForegroundColor Green
Write-Host ""

# Step 2: Process and anonymize data
Write-Host "Step 2: Anonymizing data..." -ForegroundColor Green

$data = Get-Content $tempExportFile -Raw | ConvertFrom-Json
$anonymizedUsers = @()

$counter = 0
foreach ($user in $data) {
    $userId = if ($user._id.'$oid') { $user._id.'$oid' } else { $user._id.ToString() }
    $shortId = $userId.Substring([Math]::Max(0, $userId.Length - 8))
    
    $anonymizedUser = [PSCustomObject]@{
        username = "testuser_$shortId"
        email = "testuser_$shortId@example.com"
        password = "TestPassword123!"
        firstName = "TestFirst"
        lastName = "TestLast"
        role = $user.role
        phoneNumber = "+1-555-TEST"
        address = "123 Test St, Test City, TS 00000"
        createdAt = $user.createdAt
    }
    
    $anonymizedUsers += $anonymizedUser
    $counter++
}

Write-Host "✓ Anonymized $counter users" -ForegroundColor Green
Write-Host ""

# Step 3: Clear test database
Write-Host "Step 3: Clearing Test database..." -ForegroundColor Yellow
Write-Host "⚠ WARNING: Dropping database: $Database" -ForegroundColor Yellow

kubectl exec -i $testPod -n mongodb-test -- mongosh --quiet --eval "db.getSiblingDB('$Database').dropDatabase()" | Out-Null

Write-Host "✓ Test database cleared" -ForegroundColor Green
Write-Host ""

# Step 4: Import anonymized data to test
Write-Host "Step 4: Importing anonymized data to Test..." -ForegroundColor Green

# Convert to JSON and escape for JavaScript
$anonymizedJson = $anonymizedUsers | ConvertTo-Json -Depth 10 -Compress
# Escape single quotes for JavaScript
$anonymizedJson = $anonymizedJson.Replace("'", "\'")

# Create import JavaScript file
$importJs = ".\temp-import.js"
$line1 = "db = db.getSiblingDB('$Database');"
$line2 = 'var usersData = ' + $anonymizedJson + ';'
$line3 = 'print("Importing " + usersData.length + " anonymized users...");'
$line4 = 'var result = db.users.insertMany(usersData);'
$line5 = 'print("Inserted " + Object.keys(result.insertedIds).length + " users");'

$line1 | Out-File -FilePath $importJs -Encoding UTF8
$line2 | Out-File -FilePath $importJs -Encoding UTF8 -Append
$line3 | Out-File -FilePath $importJs -Encoding UTF8 -Append
$line4 | Out-File -FilePath $importJs -Encoding UTF8 -Append
$line5 | Out-File -FilePath $importJs -Encoding UTF8 -Append

# Copy and execute
kubectl cp $importJs "mongodb-test/$testPod":/tmp/import.js
kubectl exec -i $testPod -n mongodb-test -- mongosh /tmp/import.js --quiet

Remove-Item $tempExportFile -Force
Remove-Item $importJs -Force

Write-Host "✓ Data imported to test database" -ForegroundColor Green
Write-Host ""

# Step 5: Verify
Write-Host "Step 5: Verifying data..." -ForegroundColor Green

kubectl exec -i $testPod -n mongodb-test -- mongosh --quiet --eval "db = db.getSiblingDB('$Database'); print('Total users in test: ' + db.users.countDocuments()); print('\\nSample anonymized user:'); printjson(db.users.findOne({}, {password: 0}));"

Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Refresh Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Green
Write-Host "  ✓ Production data exported"
Write-Host "  ✓ Data anonymized"
Write-Host "  ✓ Test database refreshed"
Write-Host ""
Write-Host "Anonymization applied:" -ForegroundColor Yellow
Write-Host "  • Usernames → testuser_XXXXXXXX"
Write-Host "  • Emails → testuser_XXXXXXXX@example.com"
Write-Host "  • Passwords → TestPassword123!"
Write-Host "  • Names, phones, addresses → Test data"
Write-Host ""
Write-Host "Connect to view:" -ForegroundColor Cyan
Write-Host "  MongoDB Compass: localhost:27018" -ForegroundColor White
Write-Host ""
